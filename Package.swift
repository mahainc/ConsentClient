// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ConsentClient",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .singleTargetLibrary("ConsentClient"),
        .singleTargetLibrary("ConsentClientLive"),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.9.0"),
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
            from: "3.0.0"
        ),
        .package(url: "https://github.com/mahainc/AnalyticsClient.git", exact: "3.0.0"),
        .package(url: "https://github.com/mahainc/LogClient.git", from: "0.3.0"),
        // Pinned exactly, unlike the rest: the port conformance moves in major versions.
        .package(url: "https://github.com/mahainc/FunnelClient.git", exact: "7.0.0"),
    ],
    targets: [
        .target(
            name: "ConsentClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        // ATT and UMP are implemented here rather than wrapped from separate packages. Two
        // thin packages meant three places to read when consent misbehaved, and one of them
        // linked only the interface of the others — which compiled and then answered "no
        // consent" for every user at runtime.
        .target(
            name: "ConsentClientLive",
            dependencies: [
                "ConsentClient",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(
                    name: "GoogleUserMessagingPlatform",
                    package: "swift-package-manager-google-user-messaging-platform"
                ),
                .product(name: "AnalyticsClient", package: "AnalyticsClient"),
                .product(name: "AnalyticsClientLive", package: "AnalyticsClient"),
                .product(name: "LogClient", package: "LogClient"),
                .product(name: "FunnelClient", package: "FunnelClient"),
            ]
        ),
        .testTarget(
            name: "ConsentClientTests",
            dependencies: ["ConsentClient", "ConsentClientLive"]
        ),
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}
