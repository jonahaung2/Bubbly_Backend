// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "BubblyBackend",
    platforms: [
        .macOS(.v13),
        .iOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.122.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.13.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.12.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.6.0")
    ],
    targets: [
        .executableTarget(
            name: "BubblyBackend",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "JWTKit", package: "jwt-kit")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BubblyBackendTests",
            dependencies: [
                .target(name: "BubblyBackend"),
                .product(name: "VaporTesting", package: "vapor")
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] {
    [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("ImmutableWeakCaptures")
    ]
}

