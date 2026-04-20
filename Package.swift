// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeBlinkenlights",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeBlinkenlights",
            dependencies: ["ClaudeBlinkenlightsCore"],
            path: "Sources/ClaudeBlinkenlights"
        ),
        .target(
            name: "ClaudeBlinkenlightsCore",
            path: "Sources/ClaudeBlinkenlightsCore"
        ),
        .testTarget(
            name: "ClaudeBlinkenlightsCoreTests",
            dependencies: ["ClaudeBlinkenlightsCore"],
            path: "Tests/ClaudeBlinkenlightsCoreTests"
        ),
    ]
)
