#!/bin/zsh
set -euo pipefail

service_name="com.dltldn1234.jarvis.server"
openai_account="openai-api-key"
client_account="client-token"
script_directory="${0:A:h}"
runner_path="$script_directory/run-macos-service.sh"
launch_agents_directory="$HOME/Library/LaunchAgents"
logs_directory="$HOME/Library/Logs/JarvisServer"
plist_path="$launch_agents_directory/$service_name.plist"
user_domain="gui/$(id -u)"

if ! command -v node >/dev/null 2>&1; then
  print -u2 "Node.js 22 이상을 먼저 설치해 주세요."
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(`.`)[0]')"
if (( node_major < 22 )); then
  print -u2 "Node.js 22 이상이 필요합니다. 현재 버전: $(node --version)"
  exit 1
fi

print -n "OpenAI 프로젝트 API 키를 입력하세요(화면에 표시되지 않음): "
read -rs openai_key
print
if [[ -z "$openai_key" ]]; then
  print -u2 "API 키가 비어 있어 설치를 중단합니다."
  exit 1
fi

client_token="$(openssl rand -hex 32)"
security add-generic-password -U -s "$service_name" -a "$openai_account" -w "$openai_key" >/dev/null
security add-generic-password -U -s "$service_name" -a "$client_account" -w "$client_token" >/dev/null
unset openai_key client_token

mkdir -p "$launch_agents_directory" "$logs_directory"
chmod +x "$runner_path"

escaped_runner="${runner_path//&/&amp;}"
escaped_runner="${escaped_runner//</&lt;}"
escaped_runner="${escaped_runner//>/&gt;}"

cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$service_name</string>
  <key>ProgramArguments</key>
  <array><string>$escaped_runner</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$logs_directory/server.log</string>
  <key>StandardErrorPath</key><string>$logs_directory/server.error.log</string>
  <key>ThrottleInterval</key><integer>10</integer>
</dict>
</plist>
PLIST

plutil -lint "$plist_path"
launchctl bootout "$user_domain" "$plist_path" 2>/dev/null || true
launchctl bootstrap "$user_domain" "$plist_path"
launchctl kickstart -k "$user_domain/$service_name"

for attempt in {1..20}; do
  if curl --silent --fail http://127.0.0.1:8787/health >/dev/null; then
    print "JARVIS 서버 설치 완료: http://127.0.0.1:8787"
    print "상태 확인: launchctl print $user_domain/$service_name"
    exit 0
  fi
  sleep 0.25
done

print -u2 "서버가 시작되지 않았습니다. 로그를 확인하세요: $logs_directory/server.error.log"
exit 1
