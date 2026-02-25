// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TraartApp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "TraartApp",
            dependencies: [
                .product(name: "TelemetryDeck", package: "SwiftSDK"),
            ],
            path: "Sources/TraartApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("CoreServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
