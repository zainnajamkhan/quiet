// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IndieKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "IndieKit", targets: ["IndieKit"])
    ],
    targets: [
        .target(name: "IndieKit"),
        .testTarget(name: "IndieKitTests", dependencies: ["IndieKit"])
    ]
)
