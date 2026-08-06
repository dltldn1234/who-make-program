# Personal Agent System

Mac을 주 실행 본체로 사용하고 향후 iPhone과 AirPods를 연결하는 개인 AI 에이전트입니다. 제품명은 아직 정하지 않았으며 코드에서는 중립적인 `Agent` 이름을 사용합니다.

## 현재 기능

- 한국어 텍스트 명령 해석
- 읽기 작업과 외부 상태 변경 작업의 승인 정책 분리
- 도움말, 상태, 현재 시간 응답
- 명시적 승인 후 macOS 앱 실행
- 코드 입자 1,120개로 구성된 홀로그램 코어 HUD
- 대기, 듣기, 분석, 응답 상태 애니메이션
- 네이티브 macOS 창과 메뉴바 진입점
- 명령 해석 및 정책 테스트

## 모듈 구조

```text
Apps/AgentMac        정식 macOS 앱과 메뉴바 진입점
Sources/JarvisCore   플랫폼과 UI에 독립적인 명령·승인·실행 코어
Sources/AgentUI      재사용 가능한 SwiftUI 홀로그램 HUD
Sources/JarvisCLI    코어를 빠르게 검증하는 터미널 클라이언트
Sources/JarvisHUD    SwiftPM HUD 프로토타입 실행기
Tests                코어 동작 테스트
Project.swift        재현 가능한 Xcode 프로젝트 선언
```

## 정식 macOS 앱 실행

Tuist 4 이상과 Xcode 26 이상이 필요합니다.

```sh
tuist generate
open Agent.xcworkspace
```

Xcode에서 `AgentMac` 스킴과 `My Mac` 실행 대상을 선택합니다. 생성된 `.xcodeproj`와 `.xcworkspace`는 로컬 산출물이므로 Git에 커밋하지 않습니다.

명령행 빌드:

```sh
xcodebuild \
  -workspace Agent.xcworkspace \
  -scheme AgentMac \
  -configuration Debug \
  build \
  CODE_SIGNING_ALLOWED=NO
```

## 빠른 프로토타입 실행

```sh
swift run jarvis
swift run jarvis-hud
```

HUD 명령창에서 `상태`, `몇 시야?`, `Xcode 열어줘`를 입력할 수 있습니다. 외부 동작은 확인 창에서 승인한 뒤에만 실행됩니다.

## 테스트

```sh
swift test
git diff --check
```

## 개발 원칙

- 알 수 없는 자연어를 임의의 셸 명령으로 실행하지 않습니다.
- 외부 상태를 변경하는 기능은 승인 정책을 통과해야 합니다.
- 음성, 손동작, AirPods, iPhone은 동일한 명령 코어에 입력 어댑터로 연결합니다.
- 마이크와 카메라 같은 민감한 권한은 해당 기능을 처음 사용할 때 요청합니다.

다음 단계는 실시간 음성 입력과 응답을 추가하고, 음성 에너지를 홀로그램 코어 애니메이션에 연결하는 것입니다.
