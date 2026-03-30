// swift-tools-version:5.9
import PackageDescription

let release = "2.0.2"
let checksums: [String: String] = [
    "MoaiSDK-Debug": "93440dbafb8e67584b2322ae46d699c3f0e91cdc4b3aecf4d4590df41b9ac58e",
    "MoaiSDK-Release": "0e60d080346cd9fe2f21fd569562495dce04fe9c3769152ca0b9d6670fa37eb2",
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
