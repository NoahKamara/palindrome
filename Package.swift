// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Palindrome",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "palindrome", targets: ["PalindromeCLI"]),
        .library(name: "PalindromeCore", targets: ["PalindromeCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/vapor/postgres-nio", from: "1.26.1"),
        .package(url: "https://github.com/vapor/console-kit", from: "4.15.2"),
    ],
    targets: [
        .executableTarget(
            name: "PalindromeCLI",
            dependencies: [
                "PalindromeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "ConsoleKit", package: "console-kit"),
            ],
            swiftSettings: [.enableUpcomingFeature("slash")]
        ),
        .target(
            name: "PalindromeCore",
            dependencies: [
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "ConsoleKit", package: "console-kit"),
            ],
            swiftSettings: [.enableUpcomingFeature("slash")]
        ),
        .testTarget(
            name: "PalindromeCoreTests",
            dependencies: ["PalindromeCore"]
        ),
    ]
)
