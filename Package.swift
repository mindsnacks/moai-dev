// swift-tools-version:5.9
import PackageDescription

// DEV OVERRIDE (metal-backend branch): both products resolve to the locally
// built macOS xcframework produced by xcode/libmoai/build-dev-xcframework.sh.
// Add this package directory to the Achilles workspace to override the
// remote mindsnacks/moai-dev binary dependency while developing.
//
// Before releasing from this branch, restore the URL-based binaryTargets
// (see the mindsnacks-dev version of this file); release.sh's checksum
// patching expects that form.

let devXCFramework = "xcode/libmoai/build-dev/MoaiSDK-Release.xcframework"

let package = Package(
    name: "MoaiSDK",
    products: [
        .library(name: "MoaiSDK-Debug", targets: ["MoaiSDK-Debug"]),
        .library(name: "MoaiSDK-Release", targets: ["MoaiSDK-Release"]),
    ],
    targets: [
        .binaryTarget(
            name: "MoaiSDK-Debug",
            path: devXCFramework
        ),
        .binaryTarget(
            name: "MoaiSDK-Release",
            path: devXCFramework
        ),
    ]
)
