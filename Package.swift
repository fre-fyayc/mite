// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MiteTool",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "MiteTool"
        ),
        .testTarget(
            name: "MiteToolTests",
            dependencies: [
                "MiteTool",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
