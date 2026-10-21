// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ResetExplodeMac",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ResetExplodeMac", targets: ["ResetMac"])],
    targets: [
        .target(name: "CSystem"),
        .target(name: "ResetCore", dependencies: ["CSystem"]),
        .executableTarget(name: "ResetMac", dependencies: ["ResetCore"]),
        .testTarget(name: "ResetCoreTests", dependencies: ["ResetCore"])
    ]
)
