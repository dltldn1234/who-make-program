// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "JarvisCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "JarvisCore", targets: ["JarvisCore"]),
        .executable(name: "jarvis", targets: ["JarvisCLI"]),
        .executable(name: "jarvis-hud", targets: ["JarvisHUD"])
    ],
    targets: [
        .target(name: "JarvisCore"),
        .executableTarget(name: "JarvisCLI", dependencies: ["JarvisCore"]),
        .executableTarget(name: "JarvisHUD", dependencies: ["JarvisCore"]),
        .testTarget(name: "JarvisCoreTests", dependencies: ["JarvisCore"])
    ]
)
