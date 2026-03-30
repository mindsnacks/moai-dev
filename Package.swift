// swift-tools-version:5.9
import PackageDescription

let release = "2.0.3"
let checksums: [String: String] = [
    "MoaiSDK-Debug": "6008c203148f29ce4deaf6fa372a0fc4e0f54774951c8b851067cfc870e12c59",
    "MoaiSDK-Release": "5d425ed0fadbebe93e37a564f416dc0e9e4369768f348483285b48b2e3733079",
]

let package = Package(
    name: "MoaiSDK",
    products: [
        .library(name: "MoaiSDK-Debug", targets: ["MoaiSDK-Debug"]),
        .library(name: "MoaiSDK-Release", targets: ["MoaiSDK-Release"]),
    ],
    targets: [
        .binaryTarget(
            name: "MoaiSDK-Debug",
            url: "https://github.com/mindsnacks/moai-dev/releases/download/\(release)/MoaiSDK-Debug.zip",
            checksum: checksums["MoaiSDK-Debug"]!
        ),
        .binaryTarget(
            name: "MoaiSDK-Release",
            url: "https://github.com/mindsnacks/moai-dev/releases/download/\(release)/MoaiSDK-Release.zip",
            checksum: checksums["MoaiSDK-Release"]!
        ),
    ]
)
