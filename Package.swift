// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "matter_connect",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "matter_connect", targets: ["matter_connect"])
    ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/SDL.git", from: "2.0.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.83.0")
    ],
    targets: [
        .executableTarget(
            name: "matter_connect",
            dependencies: [
                .product(name: "SDL", package: "SDL"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ]
        )
    ]
)
