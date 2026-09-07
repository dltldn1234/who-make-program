# JARVIS Brain v0.1

JARVIS Brain is the conversation and reasoning layer only. It accepts the existing
`/v1/responses` contract, calls an OpenAI-compatible OrcaRouter endpoint, and returns
text. It does not expose tools or execute shell commands, macOS actions, files,
automation, or device controls.

The Swift `JarvisCore` remains the only layer that classifies local commands and
enforces approval before a macOS action can run.

## Install

Python 3.12 and [uv](https://docs.astral.sh/uv/) are required.

```sh
cd Brain
uv sync
```

## Configure

```sh
cp .env.example .env
```

Set `ORCAROUTER_API_KEY` in `.env`. It is never committed or returned by the API.
`JARVIS_MODEL` defaults to `orcarouter/auto` and can be changed without code changes.

For compatibility with the existing Swift client, set `JARVIS_CLIENT_TOKEN` to the
same private token used by `JARVIS_CLIENT_TOKEN` in AgentMac. When this variable is
set, the Brain requires it in the `X-Jarvis-Client-Token` request header.

## Run

```sh
uv run uvicorn jarvis.app:app --host 127.0.0.1 --port 8010 --reload
```

The health endpoint works even if no API key is configured:

```sh
curl http://127.0.0.1:8010/health
```

## Test an AI response

With a configured API key, run this in another terminal:

```sh
curl http://127.0.0.1:8010/v1/responses \
  -H 'Content-Type: application/json' \
  -H "X-Jarvis-Client-Token: $JARVIS_CLIENT_TOKEN" \
  -d '{"model":"orcarouter/auto","instructions":"JARVIS conversation","input":"USER: 안녕, 자비스","store":false}'
```

The response uses the existing Node relay-compatible envelope:

```json
{"output":[{"content":[{"type":"output_text","text":"..."}]}]}
```

If `ORCAROUTER_API_KEY` is absent, `POST /v1/responses` returns a safe `503` settings
error. No real OrcaRouter request is made by the automated tests:

```sh
uv run pytest
```
