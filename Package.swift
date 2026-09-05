// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "QuantumSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "QuantumSDK",
            targets: ["QuantumSDK"]
        ),
    ],
    targets: [
        .target(
            name: "QuantumSDK",
            path: "Sources/QuantumSDK",
            swiftSettings: [
                // Complete concurrency checking: the library is consumed
                // from Swift 6 language-mode apps, so a data race here is a
                // compile error there.
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "QuantumSDKTests",
            dependencies: ["QuantumSDK"],
            path: "Tests/QuantumSDKTests"
        ),
    ]
)
