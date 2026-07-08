#!/bin/bash -e
set -e

#----------------------------------------------------------------#
# Development build: macOS-arm64-only MoaiSDK xcframework.
#
# Fast inner loop for working on MOAI source against the Achilles
# macOS app. Differences from build-xcframework.sh:
#   - macOS arm64 only (no iOS device/simulator slices)
#   - one configuration (default Release, since CoreMS links the
#     MoaiSDK-Release product in every Achilles configuration)
#   - incremental: build directory is NOT wiped between runs
#   - output is always named MoaiSDK-Release.xcframework so the
#     local Package.swift path override resolves regardless of the
#     configuration actually compiled
#   - optionally nukes the stale SPM artifact cache in a DerivedData
#     dir so Xcode picks up the fresh binary (-D <derived-data-dir>)
#----------------------------------------------------------------#

osx_schemes="libmoai-osx libmoai-osx-3rdparty libmoai-osx-zlcore libmoai-osx-luaext"

usage() {
	echo >&2 "usage: $0 [-v] [-s] [-d <dir>] [-c Debug|Release] [-D <derived-data-dir>]"
	echo >&2 "  -v          Verbose output"
	echo >&2 "  -s          Also build an iOS simulator slice (arm64+x86_64),"
	echo >&2 "              needed to build AchillesMobile against the local SDK"
	echo >&2 "  -d <dir>    Build directory (default: ./build-dev)"
	echo >&2 "  -c <config> Configuration to compile (default: Release)"
	echo >&2 "  -D <dir>    DerivedData dir whose moai-dev SPM artifacts to purge"
	exit 1
}

basedir="./build-dev"
config="Release"
verbose=false
derived_data=""
with_simulator=false

while getopts c:d:D:sv o; do
	case $o in
	c)	config=$OPTARG;;
	d)	basedir=$OPTARG;;
	D)	derived_data=$OPTARG;;
	s)	with_simulator=true;;
	v)	verbose=true;;
	\?)	usage;;
	esac
done
shift `expr $OPTIND - 1`

if [ $# -gt 0 ]; then
	usage
fi

if [ x"$config" != xDebug ] && [ x"$config" != xRelease ]; then
	usage
fi

mkdir -p "$basedir"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "Building MoaiSDK dev xcframework (macOS arm64, $config, incremental)"

build_scheme() {
	local scheme=$1
	local sdk=$2
	local archs=$3
	local build_dir="${basedir}/intermediates/${sdk}/${scheme}"
	mkdir -p "$build_dir"

	local msg="Building ${scheme} (${sdk})..."
	if $verbose; then
		echo "$msg"
		xcodebuild -project libmoai.xcodeproj \
			-scheme "$scheme" \
			-configuration "$config" \
			-sdk "$sdk" \
			ARCHS="$archs" \
			ONLY_ACTIVE_ARCH=NO \
			BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
			CONFIGURATION_BUILD_DIR="$build_dir" \
			-derivedDataPath "${basedir}/DerivedData" \
			build
	else
		printf "  %s " "$msg"
		local log="$build_dir/xcodebuild.log"
		if xcodebuild -project libmoai.xcodeproj \
			-scheme "$scheme" \
			-configuration "$config" \
			-sdk "$sdk" \
			ARCHS="$archs" \
			ONLY_ACTIVE_ARCH=NO \
			BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
			CONFIGURATION_BUILD_DIR="$build_dir" \
			build > "$log" 2>&1; then
			echo "✓"
		else
			echo "✗"
			echo "Build failed. Last 20 lines of log:"
			tail -20 "$log"
			exit 1
		fi
	fi
}

combine_libs() {
	local sdk=$1
	local schemes=$2
	local combined_dir="${basedir}/combined/${sdk}"
	mkdir -p "$combined_dir"
	local libs=""
	for scheme in $schemes; do
		libs="$libs ${basedir}/intermediates/${sdk}/${scheme}/${scheme}.a"
	done
	libtool -static -o "${combined_dir}/libmoai-combined.a" $libs
}

for scheme in $osx_schemes; do
	build_scheme "$scheme" macosx arm64
done

if $with_simulator; then
	ios_schemes="libmoai-ios libmoai-ios-3rdparty libmoai-ios-zlcore libmoai-ios-luaext"
	for scheme in $ios_schemes; do
		build_scheme "$scheme" iphonesimulator "arm64 x86_64"
	done
fi

echo "Combining libraries..."
combine_libs macosx "$osx_schemes"
if $with_simulator; then
	combine_libs iphonesimulator "$ios_schemes"
fi

echo "Copying headers..."
headers_dir="${basedir}/headers"
rm -rf "$headers_dir"
mkdir -p "$headers_dir"
rsync -a --include='*/' --include='*.h' --exclude='*' ../../src/ "$headers_dir/"
rsync -a --include='*/' --include='*.h' --exclude='*' ../../3rdparty/lua-5.1.3/src/ "$headers_dir/"

echo "Creating MoaiSDK-Release.xcframework..."
rm -rf "${basedir}/MoaiSDK-Release.xcframework"
xcframework_args=(
	-create-xcframework
	-library "${basedir}/combined/macosx/libmoai-combined.a"
	-headers "$headers_dir"
)
if $with_simulator; then
	xcframework_args+=(
		-library "${basedir}/combined/iphonesimulator/libmoai-combined.a"
		-headers "$headers_dir"
	)
fi
xcframework_args+=( -output "${basedir}/MoaiSDK-Release.xcframework" )
xcodebuild "${xcframework_args[@]}" \
	> "${basedir}/xcframework.log" 2>&1 || { cat "${basedir}/xcframework.log"; exit 1; }

if [ -n "$derived_data" ]; then
	artifact_dir="${derived_data}/SourcePackages/artifacts/moai-dev"
	if [ -d "$artifact_dir" ]; then
		echo "Purging stale SPM artifacts: $artifact_dir"
		rm -rf "$artifact_dir"
	fi
fi

echo "Done: ${basedir}/MoaiSDK-Release.xcframework"
