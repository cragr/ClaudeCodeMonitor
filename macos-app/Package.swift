// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeCodeMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClaudeCodeMonitor", targets: ["ClaudeCodeMonitor"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodeMonitor",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "ClaudeCodeMonitor/Sources"
        ),
        .testTarget(
            name: "ClaudeCodeMonitorTests",
            dependencies: ["ClaudeCodeMonitor"],
            path: "ClaudeCodeMonitorTests"
        )
    ]
)
