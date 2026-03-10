// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacMCP",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", .upToNextMinor(from: "0.11.0")),
    ],
    targets: [
        .executableTarget(
            name: "MacMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/MacMCP",
            linkerSettings: [
                .linkedFramework("EventKit"),
            ]
        ),
        .testTarget(
            name: "MacMCPTests",
            dependencies: ["MacMCP"],
            path: "Tests/MacMCPTests"
        ),
    ]
)
