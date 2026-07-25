// swift-tools-version: 6.0

import PackageDescription

// Tools version 6.0 rather than the toolchain's current 6.3: the manifest only
// needs `swiftLanguageModes`, which landed in 6.0, and a lower floor keeps the
// package resolvable from consumers on older Xcodes.
let package = Package(
    name: "swift-claude-code",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ClaudeCode",
            targets: ["ClaudeCode"]
        ),
    ],
    targets: [
        .target(
            name: "ClaudeCode",
            exclude: ["CLAUDE.md"]
        ),
        .testTarget(
            name: "ClaudeCodeTests",
            dependencies: ["ClaudeCode"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
