// swift-tools-version:5.9
import PackageDescription

let release = "v2.0.9"
let checksums: [String: String] = [
    "MoaiSDK-Debug": "078288b14b360399bab1b20d8e72a791bb1fd2bb7f3d16ce4745436c2ebcc92e",
    "MoaiSDK-Release": "644e43b9367283756f7b0358dfbde5a814068a931b8f9d5ffd05ed120227a400",
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
