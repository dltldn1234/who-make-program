#!/bin/zsh
set -euo pipefail

service_name="com.dltldn1234.jarvis.server"
openai_account="openai-api-key"
client_account="client-token"
script_directory="${0:A:h}"
server_directory="${script_directory:h}"

export OPENAI_API_KEY="$(security find-generic-password -s "$service_name" -a "$openai_account" -w)"
export JARVIS_CLIENT_TOKEN="$(security find-generic-password -s "$service_name" -a "$client_account" -w)"
export HOST="127.0.0.1"
export PORT="8787"
export OPENAI_MODEL="${OPENAI_MODEL:-gpt-5.6-terra}"

cd "$server_directory"
exec /usr/bin/env node src/server.js
