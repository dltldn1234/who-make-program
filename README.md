English | [한국어](README.ko.md)

# VANTA

**Your personal intelligence layer.**

VANTA is an open-source personal AI agent designed to connect AI reasoning with local devices, voice interfaces, tools, services, and automation.

## Overview

VANTA is a personal AI agent centered on macOS. Its device and client layer is written in Swift, while the JARVIS Brain provides the Python-based conversation and reasoning backend. VANTA uses OrcaRouter as its current LLM routing/provider layer. The existing Node.js Codex relay remains available as a legacy fallback.

JARVIS remains the internal codename and technical identifier for existing modules, packages, API paths, and environment variables.

## Features

- Korean text command interpretation
- Voice recognition and speech output
- Wake word and clap detection
- Permission-based local actions
- macOS application launching after approval
- AirPods head-motion approval and cancel controls
- Secure local Mac-iPhone communication
- TLS-based device pairing
- Keychain credential storage
- Python JARVIS Brain
- OrcaRouter LLM integration
- Legacy Node.js Codex relay fallback
- Swift and Python tests

## Architecture

```text
User
  → Swift Client
  → JarvisCore
  → Local Action or AI Request

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

LLMs cannot directly execute arbitrary shell commands or macOS actions. Local device actions remain behind the existing permission system.

## Repository Structure

```text
Apps/           Swift macOS and iPhone clients
Sources/        Swift command, permission, voice, motion, link, UI, and AI modules
Brain/          Python FastAPI conversation and reasoning service
Server/         Legacy Node.js Codex relay fallback
Tests/          Swift test suites
Package.swift   Swift Package Manager manifest
Project.swift   Tuist project declaration
```

## Getting Started

### Swift macOS client

The macOS and iPhone clients use Tuist and Xcode.

```sh
tuist generate
open Agent.xcworkspace
```

Select the `AgentMac` scheme and `My Mac` in Xcode. For a Swift package prototype:

```sh
swift run jarvis
swift run jarvis-hud
```

### Python JARVIS Brain

The Brain requires Python 3.12 and [uv](https://docs.astral.sh/uv/).

```sh
cd Brain
uv sync
cp .env.example .env
uv run uvicorn jarvis.app:app \
  --host 127.0.0.1 \
  --port 8010 \
  --reload
```

JARVIS Brain uses `127.0.0.1:8010` for local development. Configure the Swift client at runtime, without committing credentials:

```sh
export JARVIS_AI_ENDPOINT="http://127.0.0.1:8010/v1/responses"
export JARVIS_CLIENT_TOKEN="your_client_token_here"
```

Set `ORCAROUTER_API_KEY=your_api_key_here` only in `Brain/.env`. `Server/` remains available as the legacy Node.js Codex relay fallback; switching `JARVIS_AI_ENDPOINT` selects the backend.

## Security Principles

- API keys are never stored in source code.
- Secrets are stored through environment variables or Keychain.
- Local device actions require explicit permission.
- LLMs cannot directly execute arbitrary shell commands.
- Sensitive credentials must not be committed.

## Roadmap

The following capabilities are not implemented yet:

- Tool Registry
- Tool Calling
- Planner
- Memory
- Automation
- MCP integration
- Web interface
- Additional device support

## Contributing

Issues and pull requests are welcome. More detailed contribution guidelines will be added as the project matures.

## License

Licensed under the Apache License 2.0.

See [LICENSE](LICENSE) for details.
