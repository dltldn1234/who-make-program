from types import SimpleNamespace

import httpx
import pytest

from jarvis.app import create_app
from jarvis.config import Settings
from jarvis.llm import OrcaRouterProvider


class FakeCompletions:
    async def create(self, **kwargs):
        assert kwargs["model"] == "orcarouter/auto"
        assert kwargs["messages"][1] == {"role": "user", "content": "USER: 안녕"}
        return SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content="안녕하세요. 무엇을 도와드릴까요?"))]
        )


class FakeOrcaRouterClient:
    chat = SimpleNamespace(completions=FakeCompletions())


@pytest.mark.asyncio
async def test_responses_returns_a_safe_error_when_api_key_is_missing() -> None:
    settings = Settings(orcarouter_api_key=None, jarvis_client_token="test-client-token")
    app = create_app(settings=settings)
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/v1/responses",
            headers={"X-Jarvis-Client-Token": "test-client-token"},
            json={"input": "USER: 안녕"},
        )

    assert response.status_code == 503
    assert response.json() == {
        "error": {"message": "AI provider is not configured. Set ORCAROUTER_API_KEY."}
    }


@pytest.mark.asyncio
async def test_responses_matches_the_existing_swift_response_envelope_without_network() -> None:
    settings = Settings(orcarouter_api_key="not-used-in-this-test", jarvis_client_token="private-token")
    provider = OrcaRouterProvider(settings, client=FakeOrcaRouterClient())
    app = create_app(settings=settings, provider=provider)
    transport = httpx.ASGITransport(app=app)
    payload = {
        "model": "ignored-by-provider-selection",
        "instructions": "JARVIS conversation",
        "input": "USER: 안녕",
        "store": False,
    }
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/v1/responses",
            headers={"X-Jarvis-Client-Token": "private-token"},
            json=payload,
        )

    assert response.status_code == 200
    assert response.json() == {
        "output": [
            {"content": [{"type": "output_text", "text": "안녕하세요. 무엇을 도와드릴까요?"}]}
        ]
    }
