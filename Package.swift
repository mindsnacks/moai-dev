// swift-tools-version:5.9
import PackageDescription

let release = "2.0.3"
let checksums: [String: String] = [
    "MoaiSDK-Debug": "55b4f26808baada28e7ca70f335c5b9a93c297c57ce9c20b37df10f9384fecea",
    "MoaiSDK-Release": "48e192f2e9a2b5f662d83238ab7d294194700ac9d733d6beb648928ed178bd7a",
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
