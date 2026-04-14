// swift-tools-version:5.9
import PackageDescription

let release = ""
let checksums: [String: String] = [
    "MoaiSDK-Debug": "1ad8d2d6db2e76de4b8fc71c989b45e43b718fff0cd7a44e1758424f448b68f6",
    "MoaiSDK-Release": "5fc820d3635cbb06ec0326cfe59122da53d30f66e2220e0babcef7a50d7f22f6",
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
