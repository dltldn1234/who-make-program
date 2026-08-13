#!/bin/zsh
set -euo pipefail

service_name="com.dltldn1234.jarvis.server"
plist_path="$HOME/Library/LaunchAgents/$service_name.plist"
user_domain="gui/$(id -u)"

launchctl bootout "$user_domain" "$plist_path" 2>/dev/null || true
if [[ -f "$plist_path" ]]; then
  mv "$plist_path" "$HOME/.Trash/$service_name.plist"
fi
security delete-generic-password -s "$service_name" -a "openai-api-key" >/dev/null 2>&1 || true
security delete-generic-password -s "$service_name" -a "client-token" >/dev/null 2>&1 || true

print "JARVIS 서버 자동 실행과 Keychain 자격 증명을 제거했습니다."
