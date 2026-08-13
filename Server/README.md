# JARVIS Personal Server

한 명의 사용자를 위한 비공개 AI 릴레이입니다. Mac과 iPhone은 전용 클라이언트 토큰으로 이 서버에 접근하고, OpenAI API 키는 서버 환경에만 존재합니다.

## 제공 엔드포인트

- `GET /health`: 인증 없이 배포 상태 확인
- `POST /v1/responses`: `X-Jarvis-Client-Token` 인증이 필요한 대화 요청

클라이언트는 문자열 `input`만 선택할 수 있습니다. 모델, JARVIS 지침, 데이터 저장 설정, OpenAI 인증 정보는 서버가 강제합니다.

## 로컬 실행

Node.js 22 이상이 필요합니다.

```sh
cd Server
cp .env.example .env
openssl rand -hex 32
```

생성된 64자리 값을 `.env`의 `JARVIS_CLIENT_TOKEN`에 넣고, 프로젝트용 OpenAI API 키를 `OPENAI_API_KEY`에 넣습니다. `.env`는 Git에서 제외됩니다.

```sh
npm test
npm start
curl http://127.0.0.1:8787/health
```

AgentMac에는 같은 런타임 값을 전달합니다.

```sh
export JARVIS_AI_ENDPOINT="http://127.0.0.1:8787/v1/responses"
export JARVIS_CLIENT_TOKEN="the-same-64-character-token"
open -n /path/to/AgentMac.app
```

## Docker 실행

```sh
cd Server
docker compose up --build -d
docker compose ps
curl http://127.0.0.1:8787/health
```

컨테이너는 비루트 사용자, 읽기 전용 파일 시스템, 제거된 Linux capabilities, 메모리·CPU 제한으로 실행됩니다. 기본 포트는 외부 인터넷이 아닌 호스트의 loopback에만 연결됩니다.

## 외부 접속 배포

집 밖의 iPhone에서도 접근하려면 공개 포트를 직접 열지 말고 다음 중 하나를 사용합니다.

1. Tailscale 같은 개인 VPN으로 `8787` 포트에 접근
2. HTTPS 리버스 프록시 뒤에 배치하고 방화벽·접근 로그·인증 제한 적용
3. 관리형 컨테이너 호스트에 배포하고 `OPENAI_API_KEY`와 `JARVIS_CLIENT_TOKEN`을 secret으로 주입

인터넷에 노출할 때 `HOST=0.0.0.0`으로 변경할 수 있지만 TLS 없는 HTTP를 공용 네트워크에 노출하면 안 됩니다. 클라이언트 토큰이 유출되면 즉시 새 토큰을 생성하고 서버와 모든 기기에서 교체합니다.

## 운영 점검

```sh
npm run check
curl -i http://127.0.0.1:8787/health
```

서버는 대화 본문을 파일이나 데이터베이스에 저장하지 않으며 응답에 `Cache-Control: no-store`를 적용합니다. 장애 로그에도 사용자의 입력, 클라이언트 토큰, OpenAI 키를 기록하지 않습니다.

## Mac 로그인 자동 실행

Mac을 JARVIS의 상시 서버로 사용할 때 권장하는 설치 방식입니다.

```sh
cd Server
./scripts/install-macos-service.sh
```

설치 프로그램이 OpenAI 프로젝트 API 키를 보이지 않는 입력창으로 받고, API 키와 새로 생성한 256비트 클라이언트 토큰을 로그인 Keychain에 저장합니다. `launchd`가 로그인 직후 서버를 시작하고 종료되면 자동 재시작합니다.

AgentMac은 환경변수가 없을 때 같은 Keychain의 클라이언트 토큰을 찾아 `http://127.0.0.1:8787/v1/responses`에 자동 연결합니다. 첫 접근에서 macOS가 Keychain 사용 허용 여부를 물으면 AgentMac에 허용합니다. OpenAI API 키는 AgentMac이 읽지 않습니다.

```sh
curl http://127.0.0.1:8787/health
launchctl print "gui/$(id -u)/com.dltldn1234.jarvis.server"
tail -f "$HOME/Library/Logs/JarvisServer/server.error.log"
```

자동 실행과 저장된 서버 자격 증명을 제거하려면 다음을 실행합니다.

```sh
cd Server
./scripts/uninstall-macos-service.sh
```
