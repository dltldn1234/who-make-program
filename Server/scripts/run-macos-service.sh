#!/bin/zsh
set -euo pipefail

service_name="com.dltldn1234.jarvis.server"
openai_account="openai-api-key"
client_account="client-token"
script_directory="${0:A:h}"
server_directory="${script_directory:h}"

node_binary=""
for candidate in /opt/homebrew/bin/node /usr/local/bin/node /usr/bin/node; do
  if [[ -x "$candidate" ]]; then
    node_binary="$candidate"
    break
  fi
done
if [[ -z "$node_binary" ]]; then
  print -u2 "Node.js 22 이상을 찾지 못했습니다. /opt/homebrew/bin/node 또는 /usr/local/bin/node를 확인해 주세요."
  exit 127
fi

export OPENAI_API_KEY="$(security find-generic-password -s "$service_name" -a "$openai_account" -w)"
export JARVIS_CLIENT_TOKEN="$(security find-generic-password -s "$service_name" -a "$client_account" -w)"
export HOST="127.0.0.1"
export PORT="8787"
export OPENAI_MODEL="${OPENAI_MODEL:-gpt-5.6-terra}"

cd "$server_directory"
exec "$node_binary" src/server.js
