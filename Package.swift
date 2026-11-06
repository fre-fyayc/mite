// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mite-menu",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MiteMenu",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
            ]
        )
    ]
)
