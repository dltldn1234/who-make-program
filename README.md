# Personal Agent System

Mac을 주 실행 본체로 사용하고 향후 iPhone과 AirPods를 연결하는 개인 AI 에이전트입니다. 제품명은 아직 정하지 않았으며 코드에서는 중립적인 `Agent` 이름을 사용합니다.

## 현재 기능

- 한국어 텍스트 명령 해석
- 마이크 기반 실시간 한국어 음성 인식과 부분 자막
- 박수 또는 `자비스` 호출을 감지하는 상시 웨이크 모드
- 로컬 기기 명령과 AI 대화 요청을 분리하는 지능형 라우팅
- OpenAI Responses API 기반 한국어 질의응답과 음성 답변
- macOS 시스템 음성을 이용한 한국어 응답
- 음성 입력 세기에 반응하는 홀로그램 코어
- 지원되는 AirPods의 머리 움직임 추적
- 승인 대기 중 끄덕임 승인과 좌우 움직임 취소
- 읽기 작업과 외부 상태 변경 작업의 승인 정책 분리
- 도움말, 상태, 현재 시간 응답
- 명시적 승인 후 macOS 앱 실행
- 코드 입자 1,120개로 구성된 홀로그램 코어 HUD
- 대기, 듣기, 분석, 응답 상태 애니메이션
- 네이티브 macOS 창과 메뉴바 진입점
- 네이티브 iPhone 동반 앱과 6자리 페어링 화면
- Mac·iPhone이 공유하는 버전 기반 메시지 프로토콜
- Bonjour 자동 탐색과 Network.framework 기반 로컬 TCP 연결
- 페어링 완료 후 iPhone 명령을 Mac 승인 정책으로 전달
- TLS 1.3 기반 종단 간 암호화
- Keychain에 저장되는 256비트 기기 자격 증명과 자동 재연결
- 명령 해석 및 정책 테스트

## 모듈 구조

```text
Apps/AgentMac        정식 macOS 앱과 메뉴바 진입점
Apps/AgentPhone      iPhone 페어링과 원격 명령 인터페이스
Sources/JarvisCore   플랫폼과 UI에 독립적인 명령·승인·실행 코어
Sources/AgentVoice  권한·마이크 입력·음성 인식·음성 합성 계층
Sources/AgentMotion AirPods 자세 스트림과 머리 제스처 판정 계층
Sources/AgentLink   Mac·iPhone 메시지 모델과 검증 코덱
Sources/AgentIntelligence OpenAI 대화 요청·응답과 런타임 보안 설정
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

iPhone 화면은 `AgentPhone` 스킴과 iPhone 시뮬레이터 또는 실제 기기를 선택해 실행합니다. Mac 앱 상단의 6자리 코드를 입력하면 Bonjour로 발견된 Mac과 TLS 1.3 세션을 맺고 원격 명령을 보낼 수 있습니다. 두 기기는 같은 로컬 네트워크에 있어야 하며 양쪽에서 로컬 네트워크 접근을 허용해야 합니다.

최초 페어링 코드는 TLS 임시 PSK를 만드는 데 사용됩니다. 연결이 검증되면 256비트 장기 자격 증명을 암호화된 세션 안에서 발급하고 각 기기의 Keychain에 저장합니다. 이후에는 코드를 다시 입력하지 않고 해당 자격 증명으로 연결하며 네트워크가 끊기면 최대 8초 간격으로 자동 재시도합니다.

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

마이크 버튼을 누르면 macOS가 마이크와 음성 인식 권한을 요청합니다. 권한을 허용한 뒤 한국어로 명령하고 다시 버튼을 누르거나 인식이 완료될 때까지 기다리면 기존 명령 승인 정책을 거쳐 실행됩니다. 음성 데이터는 파일로 저장하지 않습니다.

앱이 실행되면 웨이크 모드가 자동으로 시작됩니다. 박수를 한 번 치거나 `자비스`라고 말하면 명령 입력 모드로 전환됩니다. `자비스 Xcode 열어줘`처럼 호출어와 명령을 한 문장으로 말할 수도 있습니다. 응답이 끝나면 웨이크 대기로 자동 복귀합니다.

## AI 대화 연결

지원하지 않는 로컬 명령이나 일반 질문은 OpenAI Responses API로 전달됩니다. API 키는 앱과 저장소에 포함하지 않으며 실행 환경에서만 읽습니다.

```sh
export OPENAI_API_KEY="your-project-api-key"
export OPENAI_MODEL="gpt-5.6-terra"
open /path/to/AgentMac.app
```

배포 환경에서는 Mac 앱에 API 키를 넣지 말고 자체 서버 릴레이를 사용합니다. 앱은 `JARVIS_AI_ENDPOINT`를 설정하면 해당 HTTPS 엔드포인트로 동일한 요청을 전송하므로, 서버에서 인증·사용량 제한·키 보관을 담당할 수 있습니다.

```sh
export JARVIS_AI_ENDPOINT="https://agent.example.com/v1/responses"
open /path/to/AgentMac.app
```

기기 실행 명령은 AI로 보내지 않고 기존 `JarvisCore` 해석기와 사용자 승인 정책으로 처리합니다. AI가 임의의 셸 명령을 생성하거나 실행할 수는 없습니다.

상단 AirPods 버튼은 모션 센서를 지원하는 AirPods가 연결된 경우 헤드 트래킹을 시작합니다. 외부 상태를 변경하는 명령의 승인 창이 표시된 동안 끄덕이면 승인하고, 고개를 좌우로 흔들면 취소합니다. 승인 대기 명령이 없을 때 감지된 움직임은 어떤 작업도 실행하지 않습니다.

## 테스트

```sh
swift test
git diff --check
```

## 개발 원칙

- 알 수 없는 자연어를 임의의 셸 명령으로 실행하지 않습니다.
- API 키와 장기 자격 증명을 소스 코드나 앱 번들에 저장하지 않습니다.
- 외부 상태를 변경하는 기능은 승인 정책을 통과해야 합니다.
- 음성, 손동작, AirPods, iPhone은 동일한 명령 코어에 입력 어댑터로 연결합니다.
- 마이크와 카메라 같은 민감한 권한은 해당 기능을 처음 사용할 때 요청합니다.

다음 단계는 사용자가 신뢰 기기를 확인·해제할 수 있는 관리 화면과 다중 기기 지원을 추가하는 것입니다.
