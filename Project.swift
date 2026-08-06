import ProjectDescription

let project = Project(
    name: "Agent",
    organizationName: "dltldn1234",
    packages: [
        .package(path: "."),
    ],
    targets: [
        .target(
            name: "AgentMac",
            destinations: .macOS,
            product: .app,
            bundleId: "com.dltldn1234.agent.mac",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "Agent",
                    "LSApplicationCategoryType": "public.app-category.productivity",
                ]
            ),
            sources: ["Apps/AgentMac/Sources/**"],
            dependencies: [
                .package(product: "AgentUI"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "SWIFT_VERSION": "6.0",
                ]
            )
        ),
    ]
)
