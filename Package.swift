// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TokenTray",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "TokenTray", path: "Sources/TokenTray")
    ]
)
