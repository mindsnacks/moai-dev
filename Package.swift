// swift-tools-version:5.9
import PackageDescription

let release = "2.0.5"
let checksums: [String: String] = [
    "MoaiSDK-Debug": "9dc306ffc7aa4833f9ccb6d2772cec7e5237bb8159182f47a0e1ff9cdf5841a9",
    "MoaiSDK-Release": "88b0b7e3696f9fa13fcf7b66e9f8aa5c83258183882040cc4740a6cad9b22d35",
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
