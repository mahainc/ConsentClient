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
        .package(url: "https://github.com/mahainc/ATTClient.git", from: "1.0.0"),
        .package(url: "https://github.com/mahainc/UMPClient.git", from: "1.0.1"),
        .package(url: "https://github.com/mahainc/LogClient.git", from: "0.3.0"),
        .package(url: "https://github.com/mahainc/FunnelClient.git", exact: "7.0.0"),
    ],
    targets: [
        .target(
            name: "ConsentClient",
            dependencies: [
                .product(name: "UMPClient", package: "UMPClient")
            ]
        ),
        .target(
            name: "ConsentClientLive",
            dependencies: [
                "ConsentClient",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ATTClient", package: "ATTClient"),
                .product(name: "UMPClient", package: "UMPClient"),
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
