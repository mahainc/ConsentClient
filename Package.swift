// swift-tools-version: 6.1

import PackageDescription

/// The `Funnel` trait's name, shared by its declaration below and by every product
/// condition that gates on it. The matching `#if Funnel` in the conformer cannot
/// reference this — a compiler condition is not a Swift expression — but these two
/// manifest-level uses can, and a typo in either would silently stop gating.
let funnelTrait = "Funnel"

let package = Package(
    name: "ConsentClient",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .singleTargetLibrary("ConsentClient"),
        .singleTargetLibrary("ConsentClientLive"),
    ],
    // The funnel conformer is opt-in. A consumer that wants UMP and ATT — which is what
    // this package is for — should not also pay for FunnelClient + LogClient in its
    // dependency graph just to get them. `#if canImport(FunnelClient)` cannot do this: it
    // is evaluated after resolution, so the dependency is already fetched and built by the
    // time the compiler sees it. A trait gates the edge itself.
    //
    // Off by default, so adding this package never widens a graph by surprise:
    //   .package(url: "…/ConsentClient.git", from: "2.2.0")                  // UMP + ATT only
    //   .package(url: "…/ConsentClient.git", from: "2.2.0", traits: ["Funnel"])
    traits: [
        .default(enabledTraits: ["Funnel"]),
        Trait(
            name: funnelTrait,
            description: "Conform ConsentClient to FunnelClient's Consent port."
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.9.0"),
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
            from: "3.0.0"
        ),
        .package(url: "https://github.com/mahainc/AnalyticsClient.git", from: "3.0.2"),
        .package(url: "https://github.com/mahainc/LogClient.git", from: "0.3.0"),
        // Floored at a major, not pinned exactly: `Consent.Providing` is the port
        // ConsentClient+Funnel.swift conforms to, and it moves in major versions — so 9.x
        // is safe to follow and 10.0 has to be adopted deliberately.
        .package(url: "https://github.com/mahainc/FunnelClient.git", from: "9.0.0"),
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
                // Funnel-only: LogClient is named nowhere but ConsentClient+Funnel.swift,
                // and FunnelClient nowhere but the conformance it declares.
                .product(
                    name: "LogClient",
                    package: "LogClient",
                    condition: .when(traits: [funnelTrait])
                ),
                .product(
                    name: "FunnelClient",
                    package: "FunnelClient",
                    condition: .when(traits: [funnelTrait])
                ),
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
