// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TraartApp",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TraartApp",
            dependencies: [],
            path: "Sources/TraartApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("CoreServices"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
