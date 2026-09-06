[English](README.md) | 한국어

# VANTA

**당신을 위한 개인 지능 레이어.**

VANTA는 AI의 추론 능력을 로컬 기기, 음성 인터페이스, 도구, 서비스 및 자동화와 연결하기 위한 오픈소스 개인 AI 에이전트입니다.

## 개요

VANTA는 macOS를 중심으로 동작하는 개인 AI 에이전트입니다. 기기 제어와 클라이언트 계층은 Swift로 작성되며, JARVIS Brain이 Python 기반 대화·추론 백엔드를 담당합니다. 현재 LLM 라우팅·provider 계층으로 OrcaRouter를 사용합니다. 기존 Node.js Codex relay는 legacy fallback으로 유지됩니다.

JARVIS는 기존 모듈, package, API path, 환경 변수에 사용되는 내부 codename 및 기술 식별자로 유지됩니다.

## 기능

- 한국어 텍스트 명령 해석
- 음성 인식과 음성 응답
- 웨이크 워드와 박수 감지
- 승인 기반 로컬 동작
- 승인 후 macOS 앱 실행
- AirPods 머리 움직임을 통한 승인·취소 제어
- 안전한 로컬 Mac-iPhone 통신
- TLS 기반 기기 페어링
- Keychain 자격 증명 저장
- Python JARVIS Brain
- OrcaRouter LLM 연동
- Legacy Node.js Codex relay fallback
- Swift 및 Python 테스트

## 아키텍처

```text
사용자
  → Swift Client
  → JarvisCore
  → Local Action 또는 AI Request

Local Action
  JarvisCore
  → Permission
  → MacActionExecutor

AI Request
  AgentIntelligence
  → Python JARVIS Brain
  → OrcaRouter
  → LLM
```

LLM은 임의의 shell command나 macOS 동작을 직접 실행할 수 없습니다. 로컬 기기 동작은 기존 Permission 시스템을 반드시 통과합니다.

## 저장소 구조

```text
Apps/           Swift macOS 및 iPhone 클라이언트
Sources/        Swift 명령, 승인, 음성, 모션, 연결, UI, AI 모듈
Brain/          Python FastAPI 기반 대화·추론 서비스
Server/         Legacy Node.js Codex relay fallback
Tests/          Swift 테스트 모음
Package.swift   Swift Package Manager manifest
Project.swift   Tuist 프로젝트 선언
```

## 시작하기

### Swift macOS 클라이언트

macOS와 iPhone 클라이언트는 Tuist와 Xcode를 사용합니다.

```sh
tuist generate
open Agent.xcworkspace
```

Xcode에서 `AgentMac` 스킴과 `My Mac`을 선택합니다. Swift Package 프로토타입은 다음처럼 실행할 수 있습니다.

```sh
swift run jarvis
swift run jarvis-hud
```

### Python JARVIS Brain

Brain에는 Python 3.12와 [uv](https://docs.astral.sh/uv/)가 필요합니다.

```sh
cd Brain
uv sync
cp .env.example .env
uv run uvicorn jarvis.app:app \
  --host 127.0.0.1 \
  --port 8010 \
  --reload
```

로컬 개발에서 JARVIS Brain은 `127.0.0.1:8010`을 사용합니다. 자격 증명은 커밋하지 않고 Swift 클라이언트 실행 환경에 설정합니다.

```sh
export JARVIS_AI_ENDPOINT="http://127.0.0.1:8010/v1/responses"
export JARVIS_CLIENT_TOKEN="your_client_token_here"
```

`ORCAROUTER_API_KEY=your_api_key_here`는 `Brain/.env`에만 설정합니다. `Server/`는 legacy Node.js Codex relay fallback으로 유지되며, `JARVIS_AI_ENDPOINT`를 바꾸어 백엔드를 선택할 수 있습니다.

## 보안 원칙

- API key는 source code에 저장하지 않습니다.
- secret은 환경 변수 또는 Keychain으로 관리합니다.
- 로컬 기기 동작에는 명시적인 승인이 필요합니다.
- LLM은 임의의 shell command를 직접 실행할 수 없습니다.
- 민감한 자격 증명은 커밋하지 않습니다.

## 로드맵

다음 기능은 아직 구현되지 않았습니다.

- Tool Registry
- Tool Calling
- Planner
- Memory
- Automation
- MCP integration
- Web interface
- 추가 기기 지원

## 기여하기

Issue와 pull request를 환영합니다. 상세한 기여 가이드는 프로젝트가 성장하면서 추가할 예정입니다.

## 라이선스

Apache License 2.0을 따릅니다.

자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
