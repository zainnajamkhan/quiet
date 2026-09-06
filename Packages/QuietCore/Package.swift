// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "QuietCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "QuietCore", targets: ["QuietCore"])
    ],
    targets: [
        .target(name: "QuietCore"),
        .testTarget(name: "QuietCoreTests", dependencies: ["QuietCore"])
    ]
)
