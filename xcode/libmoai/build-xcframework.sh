#!/bin/bash -e
set -e

#----------------------------------------------------------------#
# Build Moai XCFramework
# Combines libmoai iOS and macOS schemes into a single xcframework
# Supports both Debug and Release configurations
#----------------------------------------------------------------#

# Schemes to include in the combined framework, per platform
ios_schemes="libmoai-ios libmoai-ios-3rdparty libmoai-ios-zlcore libmoai-ios-luaext"
osx_schemes="libmoai-osx libmoai-osx-3rdparty libmoai-osx-zlcore libmoai-osx-luaext"

usage() {
	echo >&2 "usage: $0 [-v] [-d <dir>] [-c Debug|Release|all]"
	echo >&2 "  -v          Verbose output"
	echo >&2 "  -d <dir>    Build directory (default: ./build)"
	echo >&2 "  -c <config> Configuration: Debug, Release, or all (default: all)"
	exit 1
}

basedir="./build"
configurations="all"
verbose=false

while getopts c:d:v o; do
	case $o in
	c)	configurations=$OPTARG;;
	d)	basedir=$OPTARG;;
	v)	verbose=true;;
	\?)	usage;;
	esac
done
shift `expr $OPTIND - 1`

if [ $# -gt 0 ]; then
	usage
fi

# Validate configuration
if [ x"$configurations" != xDebug ] && [ x"$configurations" != xRelease ] && [ x"$configurations" != xall ]; then
	usage
elif [ x"$configurations" = xall ]; then
	configurations="Debug Release"
fi

# Clean and create build directory
rm -rf "$basedir"
mkdir -p "$basedir"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "========================================"
echo "Building Moai XCFramework"
echo "========================================"
echo "Output directory: $basedir"
echo "Configurations: $configurations"
echo ""

build_scheme() {
	local scheme=$1
	local sdk=$2
	local config=$3
	local archs=$4

	local build_dir="${basedir}/intermediates/${config}/${sdk}/${scheme}"
	mkdir -p "$build_dir"

	local msg="Building ${scheme} for ${sdk} (${config})..."

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

for config in $configurations; do
	echo "----------------------------------------"
	echo "Configuration: $config"
	echo "----------------------------------------"

	# Build all schemes for iOS device (arm64)
	echo "Building for iOS Device (arm64)..."
	for scheme in $ios_schemes; do
		build_scheme "$scheme" "iphoneos" "$config" "arm64"
	done

	# Build all schemes for iOS simulator (arm64 + x86_64)
	echo ""
	echo "Building for iOS Simulator (arm64, x86_64)..."
	for scheme in $ios_schemes; do
		build_scheme "$scheme" "iphonesimulator" "$config" "arm64 x86_64"
	done

	# Build all schemes for macOS (arm64 + x86_64)
	echo ""
	echo "Building for macOS (arm64, x86_64)..."
	for scheme in $osx_schemes; do
		build_scheme "$scheme" "macosx" "$config" "arm64 x86_64"
	done

	echo ""
	echo "Creating combined libraries..."

	# Combine all scheme libraries for device
	device_dir="${basedir}/intermediates/${config}/iphoneos/combined"
	mkdir -p "$device_dir"
	device_libs=""
	for scheme in $ios_schemes; do
		device_libs="$device_libs ${basedir}/intermediates/${config}/iphoneos/${scheme}/${scheme}.a"
	done

	printf "  Combining device libraries... "
	libtool -static -o "${device_dir}/libmoai-combined.a" $device_libs
	echo "✓"

	# Combine all scheme libraries for simulator
	sim_dir="${basedir}/intermediates/${config}/iphonesimulator/combined"
	mkdir -p "$sim_dir"
	sim_libs=""
	for scheme in $ios_schemes; do
		sim_libs="$sim_libs ${basedir}/intermediates/${config}/iphonesimulator/${scheme}/${scheme}.a"
	done

	printf "  Combining simulator libraries... "
	libtool -static -o "${sim_dir}/libmoai-combined.a" $sim_libs
	echo "✓"

	# Combine all scheme libraries for macOS
	macos_dir="${basedir}/intermediates/${config}/macosx/combined"
	mkdir -p "$macos_dir"
	macos_libs=""
	for scheme in $osx_schemes; do
		macos_libs="$macos_libs ${basedir}/intermediates/${config}/macosx/${scheme}/${scheme}.a"
	done

	printf "  Combining macOS libraries... "
	libtool -static -o "${macos_dir}/libmoai-combined.a" $macos_libs
	echo "✓"

	# Copy headers from source tree, preserving directory structure
	headers_dir="${basedir}/intermediates/${config}/headers"
	mkdir -p "$headers_dir"
	rsync -a --include='*/' --include='*.h' --exclude='*' ../../src/ "$headers_dir/"
	rsync -a --include='*/' --include='*.h' --exclude='*' ../../3rdparty/lua-5.1.3/src/ "$headers_dir/"
	cp -R "$headers_dir" "${device_dir}/include"
	cp -R "$headers_dir" "${sim_dir}/include"
	cp -R "$headers_dir" "${macos_dir}/include"
	echo "  Headers copied ✓"

	echo ""
	echo "Creating XCFramework for ${config}..."

	# Create xcframework (-headers must follow each -library)
	xcframework_args=(
		-create-xcframework
		-library "${device_dir}/libmoai-combined.a"
	)
	if [ -d "${device_dir}/include" ]; then
		xcframework_args+=(-headers "${device_dir}/include")
	fi
	xcframework_args+=(-library "${sim_dir}/libmoai-combined.a")
	if [ -d "${sim_dir}/include" ]; then
		xcframework_args+=(-headers "${sim_dir}/include")
	fi
	xcframework_args+=(-library "${macos_dir}/libmoai-combined.a")
	if [ -d "${macos_dir}/include" ]; then
		xcframework_args+=(-headers "${macos_dir}/include")
	fi
	xcframework_args+=(-output "${basedir}/MoaiSDK-${config}.xcframework")

	printf "  Creating MoaiSDK-${config}.xcframework... "
	if xcodebuild "${xcframework_args[@]}" > "${basedir}/xcframework-${config}.log" 2>&1; then
		echo "✓"
	else
		echo "✗"
		echo "XCFramework creation failed. Log:"
		cat "${basedir}/xcframework-${config}.log"
		exit 1
	fi

	echo ""
done

echo "========================================"
echo "Build Complete!"
echo "========================================"
echo ""
echo "XCFrameworks created:"
for config in $configurations; do
	echo "  ${basedir}/MoaiSDK-${config}.xcframework"
done
echo ""
echo "To use in your Xcode project:"
echo "1. Drag the .xcframework into your project"
echo "2. In 'Frameworks, Libraries, and Embedded Content', ensure it's set to 'Embed & Sign' or 'Do Not Embed' based on your needs"
echo "3. Clean and rebuild your project"
echo ""
