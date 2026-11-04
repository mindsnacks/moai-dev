// swift-tools-version:5.9
import PackageDescription

let release = "v2.0.10"
let checksums: [String: String] = [
    "MoaiSDK-Debug": "5af8959a1f7614e3853af3e930bf853bb043a1cd7a258942e2b88a679159602f",
    "MoaiSDK-Release": "cba4784e802016cd3ad78a1859ad459fd7e7236757c469efaa57d1f157eafed1",
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
