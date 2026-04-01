// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhotoLocSync",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PhotoLocSyncCore", targets: ["PhotoLocSyncCore"]),
        .library(name: "PhotoLocSyncAdapters", targets: ["PhotoLocSyncAdapters"]),
        .executable(name: "PhotoLocSyncMac", targets: ["PhotoLocSyncMac"])
    ],
    targets: [
        .target(
            name: "PhotoLocSyncCore",
            path: "Sources/PhotoLocSyncCore"
        ),
        .target(
            name: "PhotoLocSyncAdapters",
            dependencies: ["PhotoLocSyncCore"],
            path: "Sources/PhotoLocSyncAdapters"
        ),
        .executableTarget(
            name: "PhotoLocSyncMac",
            dependencies: ["PhotoLocSyncCore", "PhotoLocSyncAdapters"],
            path: "App/PhotoLocSyncMac"
        ),
        .testTarget(
            name: "PhotoLocSyncCoreTests",
            dependencies: ["PhotoLocSyncCore"],
            path: "Tests/PhotoLocSyncCoreTests"
        ),
        .testTarget(
            name: "PhotoLocSyncAdapterTests",
            dependencies: ["PhotoLocSyncCore", "PhotoLocSyncAdapters"],
            path: "Tests/PhotoLocSyncAdapterTests",
            resources: [
                .process("Fixtures")
            ]
        ),
        .testTarget(
            name: "PhotoLocSyncManualTests",
            dependencies: ["PhotoLocSyncCore", "PhotoLocSyncAdapters"],
            path: "Tests/PhotoLocSyncManualTests",
            exclude: ["MANUAL_TEST_GUIDE.md"]
        ),
        .testTarget(
            name: "PhotoLocSyncMacTests",
            dependencies: ["PhotoLocSyncMac", "PhotoLocSyncCore", "PhotoLocSyncAdapters"],
            path: "Tests/PhotoLocSyncMacTests"
        )
    ]
)
