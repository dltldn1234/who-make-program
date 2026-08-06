# JARVIS Core

Mac을 실행 본체로 사용하는 개인 비서의 첫 번째 코어입니다.

현재 포함된 기능:

- 한국어 텍스트 명령 해석
- 실행 전 승인 정책
- 도움말, 상태, 현재 시간 응답
- 승인 후 macOS 앱 실행
- 명령 해석 및 정책 테스트

실행:

```sh
swift run jarvis
```

Mac HUD 프로토타입 실행:

```sh
swift run jarvis-hud
```

HUD 하단 명령창에서 `상태`, `몇 시야?`, `Xcode 열어줘`를 입력할 수 있습니다.
외부 동작은 확인 창에서 승인한 뒤에만 실행됩니다.

테스트:

```sh
swift test
```

다음 단계는 이 코어를 SwiftUI 메뉴바 앱에 연결하고, 이후 iPhone 클라이언트와 AirPods 음성·머리 제스처 입력을 추가하는 것입니다.
