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
                    "NSCameraUsageDescription": "손동작으로 홀로그램 인터페이스를 제어하기 위해 카메라를 사용합니다.",
                    "NSMicrophoneUsageDescription": "음성 명령을 듣고 처리하기 위해 마이크를 사용합니다.",
                    "NSMotionUsageDescription": "지원되는 AirPods의 머리 움직임을 명령 승인과 제어에 사용합니다.",
                    "NSSpeechRecognitionUsageDescription": "음성 명령을 기기에서 텍스트로 변환하기 위해 음성 인식을 사용합니다.",
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
