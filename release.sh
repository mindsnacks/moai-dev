#!/bin/bash
set -euo pipefail

usage() {
	echo >&2 "usage: $0 [--apple] [--android] <version>"
	echo >&2 "  version   Release version (e.g. 2.0.3)"
	echo >&2 "  --apple   Build and upload Apple XCFrameworks only"
	echo >&2 "  --android Build and upload Android SDK only"
	echo >&2 ""
	echo >&2 "If neither --apple nor --android is given, both are built and uploaded."
	echo >&2 ""
	echo >&2 "Builds selected release artifacts, creates a GitHub release,"
	echo >&2 "then updates Package.swift with checksums from the uploaded assets."
	exit 1
}

build_apple=false
build_android=false

while [[ $# -gt 0 ]]; do
	case "$1" in
		--apple)   build_apple=true;   shift ;;
		--android) build_android=true; shift ;;
		-*)        usage ;;
		*)         break ;;
	esac
done

if [ $# -ne 1 ]; then
	usage
fi

if ! $build_apple && ! $build_android; then
	build_apple=true
	build_android=true
fi

version="$1"
tag="v${version}"
repo_root="$(cd "$(dirname "$0")" && pwd)"
build_dir="$repo_root/build"
repo_name="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"


# Preflight checks
required_cmds=(gh zip shasum)
$build_apple   && required_cmds+=(xcodebuild)
$build_android && required_cmds+=(ndk-build rsync)
for cmd in "${required_cmds[@]}"; do
	if ! command -v "$cmd" &>/dev/null; then
		echo >&2 "error: $cmd not found in PATH"
		exit 1
	fi
done

if ! gh auth status &>/dev/null; then
	echo >&2 "error: not authenticated with gh. Run 'gh auth login' first."
	exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
	echo >&2 "error: working tree is not clean. Commit or stash changes first."
	exit 1
fi

echo "========================================"
echo "Releasing MoaiSDK ${version} (${tag})"
echo "========================================"
echo ""

# --- Apple (XCFrameworks) ---
if $build_apple; then
	echo "Building Apple XCFrameworks..."
	bash "$repo_root/xcode/libmoai/build-xcframework.sh" -d "$build_dir"

	echo ""
	echo "Zipping XCFrameworks..."
	for xcf in "$build_dir"/MoaiSDK-*.xcframework; do
		name=$(basename "$xcf" .xcframework)
		(cd "$build_dir" && zip -r "${name}.zip" "$(basename "$xcf")")
		echo "  $build_dir/${name}.zip"
	done
fi

# --- Android ---
if $build_android; then
	echo ""
	echo "Building Android libraries..."
	(cd "$repo_root/ant/libmoai" && bash build.sh -a all)

	echo ""
	echo "Packaging Android SDK..."
	staging="$build_dir/MoaiSDK-Android"
	mkdir -p "$staging/lib"

	for abi in arm64-v8a armeabi-v7a x86 x86_64; do
		mkdir -p "$staging/lib/$abi"
		cp "$repo_root/ant/libmoai/libs/$abi/libmoai.so" "$staging/lib/$abi/"
	done

	mkdir -p "$staging/include/src" "$staging/include/3rdparty"
	rsync -a --include='*/' --include='*.h' --exclude='*' "$repo_root/src/" "$staging/include/src/"
	rsync -a --include='*/' --include='*.h' --exclude='*' "$repo_root/3rdparty/" "$staging/include/3rdparty/"

	(cd "$build_dir" && zip -r MoaiSDK-Android.zip MoaiSDK-Android)
fi

# --- Tag and push ---
echo ""
echo "Tagging ${tag}..."
git -C "$repo_root" tag -f "$tag"

echo "Pushing..."
git -C "$repo_root" push
git -C "$repo_root" push -f origin "$tag"

# --- GitHub release and asset upload ---
echo ""
echo "Creating GitHub release..."
gh release create "$tag" --title "$tag" --generate-notes

echo ""
echo "Uploading release assets..."
for zip in "$build_dir"/*.zip; do
	echo "  $(basename "$zip")"
	gh release upload "$tag" "$zip"
done

# --- Publish Android SDK to GitHub Packages Maven ---
if $build_android; then
	echo ""
	echo "Publishing Android SDK to GitHub Packages Maven..."
	github_token="$(gh auth token)"
	maven_base="https://maven.pkg.github.com/${repo_name}/com/mindsnacks/moai-sdk-android/${version}"

	cat > "$build_dir/moai-sdk-android-${version}.pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.mindsnacks</groupId>
  <artifactId>moai-sdk-android</artifactId>
  <version>${version}</version>
  <packaging>zip</packaging>
</project>
EOF

	curl -fsS -X PUT \
		-H "Authorization: token ${github_token}" \
		-H "Content-Type: application/xml" \
		--data-binary "@${build_dir}/moai-sdk-android-${version}.pom" \
		"${maven_base}/moai-sdk-android-${version}.pom"

	curl -fsS -X PUT \
		-H "Authorization: token ${github_token}" \
		-H "Content-Type: application/zip" \
		--data-binary "@${build_dir}/MoaiSDK-Android.zip" \
		"${maven_base}/moai-sdk-android-${version}.zip"

	echo "  Published com.mindsnacks:moai-sdk-android:${version}"
fi

echo ""
echo "========================================"
echo "Release ${tag} complete!"
echo "========================================"
