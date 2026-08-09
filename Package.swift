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
        .library(name: "AgentVoice", targets: ["AgentVoice"]),
        .library(name: "AgentMotion", targets: ["AgentMotion"]),
        .library(name: "AgentLink", targets: ["AgentLink"]),
        .library(name: "AgentUI", targets: ["AgentUI"]),
        .executable(name: "jarvis", targets: ["JarvisCLI"]),
        .executable(name: "jarvis-hud", targets: ["JarvisHUD"])
    ],
    targets: [
        .target(name: "JarvisCore"),
        .target(name: "AgentVoice"),
        .target(name: "AgentMotion"),
        .target(name: "AgentLink"),
        .target(name: "AgentUI", dependencies: ["JarvisCore", "AgentVoice", "AgentMotion"]),
        .executableTarget(name: "JarvisCLI", dependencies: ["JarvisCore"]),
        .executableTarget(name: "JarvisHUD", dependencies: ["AgentUI"]),
        .testTarget(name: "JarvisCoreTests", dependencies: ["JarvisCore"]),
        .testTarget(name: "AgentVoiceTests", dependencies: ["AgentVoice"]),
        .testTarget(name: "AgentMotionTests", dependencies: ["AgentMotion"]),
        .testTarget(name: "AgentLinkTests", dependencies: ["AgentLink"])
    ]
)
