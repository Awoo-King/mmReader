// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mmReaderCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "mmReaderCore",
            targets: ["mmReaderCore"]
        ),
        .library(
            name: "mmReaderUI",
            targets: ["mmReaderUI"]
        ),
        .executable(
            name: "mmReaderApp",
            targets: ["mmReaderApp"]
        )
    ],
    targets: [
        .target(
            name: "mmReaderCore"
        ),
        .target(
            name: "mmReaderUI",
            dependencies: ["mmReaderCore"]
        ),
        .executableTarget(
            name: "mmReaderApp",
            dependencies: ["mmReaderUI", "mmReaderCore"]
        ),
        .testTarget(
            name: "mmReaderCoreTests",
            dependencies: ["mmReaderCore", "mmReaderUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
