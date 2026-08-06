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
        .library(name: "AgentUI", targets: ["AgentUI"]),
        .executable(name: "jarvis", targets: ["JarvisCLI"]),
        .executable(name: "jarvis-hud", targets: ["JarvisHUD"])
    ],
    targets: [
        .target(name: "JarvisCore"),
        .target(name: "AgentUI", dependencies: ["JarvisCore"]),
        .executableTarget(name: "JarvisCLI", dependencies: ["JarvisCore"]),
        .executableTarget(name: "JarvisHUD", dependencies: ["AgentUI"]),
        .testTarget(name: "JarvisCoreTests", dependencies: ["JarvisCore"])
    ]
)
