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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ClaudeCodeMonitor",
            dependencies: [],
            path: "ClaudeCodeMonitor/Sources"
        ),
        .testTarget(
            name: "ClaudeCodeMonitorTests",
            dependencies: ["ClaudeCodeMonitor"],
            path: "ClaudeCodeMonitorTests"
        )
    ]
)
