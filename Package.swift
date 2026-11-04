// swift-tools-version:5.10
// G.ai Token Tray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import PackageDescription

let package = Package(
    name: "TokenTray",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "TokenTray", path: "Sources/TokenTray")
    ]
)
