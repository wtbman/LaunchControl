// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LaunchControl",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "LaunchControl",
            targets: ["LaunchControl"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LaunchControl",
            path: "Sources"
        )
    ]
)
