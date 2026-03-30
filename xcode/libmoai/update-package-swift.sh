#!/bin/bash
set -e

usage() {
	echo >&2 "usage: $0 <version> <build-dir>"
	echo >&2 "  version    Release version (e.g. 2.0.3)"
	echo >&2 "  build-dir  Directory containing MoaiSDK-*.xcframework directories"
	exit 1
}

if [ $# -ne 2 ]; then
	usage
fi

version="$1"
build_dir="$2"

for xcf in "$build_dir/MoaiSDK-Debug.xcframework" "$build_dir/MoaiSDK-Release.xcframework"; do
	if [ ! -d "$xcf" ]; then
		echo >&2 "error: $xcf not found"
		exit 1
	fi
done

echo "Zipping XCFrameworks..."
for xcf in "$build_dir"/MoaiSDK-*.xcframework; do
	name=$(basename "$xcf" .xcframework)
	zip_path="$build_dir/${name}.zip"
	(cd "$build_dir" && zip -r "${name}.zip" "$(basename "$xcf")")
	echo "  $zip_path"
done

debug_checksum=$(shasum -a 256 "$build_dir/MoaiSDK-Debug.zip" | awk '{print $1}')
release_checksum=$(shasum -a 256 "$build_dir/MoaiSDK-Release.zip" | awk '{print $1}')

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
package_swift="$repo_root/Package.swift"

sed -i '' "s/^let release = .*/let release = \"${version}\"/" "$package_swift"
sed -i '' "s/\"MoaiSDK-Debug\": \".*\"/\"MoaiSDK-Debug\": \"${debug_checksum}\"/" "$package_swift"
sed -i '' "s/\"MoaiSDK-Release\": \".*\"/\"MoaiSDK-Release\": \"${release_checksum}\"/" "$package_swift"

echo "Updated $package_swift"
echo "  version:          $version"
echo "  MoaiSDK-Debug:    $debug_checksum"
echo "  MoaiSDK-Release:  $release_checksum"
