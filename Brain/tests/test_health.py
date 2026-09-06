import httpx
import pytest

from jarvis.app import create_app
from jarvis.config import Settings


@pytest.mark.asyncio
async def test_health_succeeds_without_an_api_key() -> None:
    app = create_app(settings=Settings(orcarouter_api_key=None))
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "jarvis-brain", "version": "0.1.0"}
