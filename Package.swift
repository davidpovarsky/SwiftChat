// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftChat",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "SwiftChatCore", targets: ["SwiftChatCore"]),
        .library(name: "SwiftChatUI", targets: ["SwiftChatUI"]),
        .library(name: "SwiftChatOpenAI", targets: ["SwiftChatOpenAI"]),
        .library(name: "SwiftChat", targets: ["SwiftChat"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/tinfoilsh/openai-swift-fork.git",
            from: "0.0.4"
        ),
        .package(
            url: "https://github.com/tinfoilsh/textual",
            branch: "main"
        ),
        .package(
            url: "https://github.com/mgriebling/SwiftMath",
            from: "1.7.3"
        ),
    ],
    targets: [
        .target(name: "SwiftChatCore"),
        .target(
            name: "SwiftChatUI",
            dependencies: [
                "SwiftChatCore",
                .product(name: "Textual", package: "textual"),
                .product(name: "SwiftMath", package: "SwiftMath"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "SwiftChatOpenAI",
            dependencies: [
                "SwiftChatCore",
                .product(name: "OpenAI", package: "openai-swift-fork"),
            ]
        ),
        .target(
            name: "SwiftChat",
            dependencies: [
                "SwiftChatCore",
                "SwiftChatUI",
                "SwiftChatOpenAI",
            ]
        ),
        .testTarget(
            name: "SwiftChatCoreTests",
            dependencies: ["SwiftChatCore"]
        ),
        .testTarget(
            name: "SwiftChatUITests",
            dependencies: ["SwiftChatCore", "SwiftChatUI"]
        ),
        .testTarget(
            name: "SwiftChatPublicAPITests",
            dependencies: ["SwiftChat", "SwiftChatCore", "SwiftChatUI"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
