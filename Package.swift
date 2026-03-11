// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Promptly",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Promptly",
            targets: ["Promptly"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Promptly",
            path: "Promptly",
            exclude: ["Info.plist", "Promptly.entitlements"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PromptlyTests",
            dependencies: ["Promptly"],
            path: "PromptlyTests"
        )
    ]
)
