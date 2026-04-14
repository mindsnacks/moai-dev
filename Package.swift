// swift-tools-version:5.9
import PackageDescription

let release = "v2.0.6"
let checksums: [String: String] = [
    "MoaiSDK-Debug": "d7c13e03b6cfc9d575b8a63a82691e424ed523799f86fd1e01675f791db62c15",
    "MoaiSDK-Release": "1518a2c38cd26b6a7f9a19bd7dc344c6c67090d4f193f219030b2fc51311b434",
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
