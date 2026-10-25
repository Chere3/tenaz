// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TenazCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TenazCore", targets: ["TenazCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1"),
    ],
    targets: [
        .target(
            name: "TenazCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/TenazCore",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "TenazCoreTests",
            dependencies: ["TenazCore"],
            path: "Tests/TenazCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
