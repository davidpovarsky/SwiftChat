// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PackageExample",
    platforms: [.iOS(.v18)],
    products: [
        .executable(name: "PackageExample", targets: ["PackageExample"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "PackageExample",
            dependencies: [
                .product(name: "SwiftChat", package: "SwiftChat"),
                .product(name: "SwiftChatCore", package: "SwiftChat"),
                .product(name: "SwiftChatUI", package: "SwiftChat"),
            ],
            path: "PackageExample"
        ),
    ],
    swiftLanguageModes: [.v5]
)
