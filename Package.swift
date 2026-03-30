// swift-tools-version:5.9
import PackageDescription

let release = "2.0.3"
let checksums: [String: String] = [
    "MoaiSDK-Debug": "1aeb7b7e498d6f81732fdd162428766d35e05dac48e0c574359626f75d79f45f",
    "MoaiSDK-Release": "faae0f8d7ddaa62691f74bb2b4a5c37ea925ccd81da4e9ba145ab76ace640456",
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
