"""Compatibility endpoint for the existing AgentIntelligence client."""

from typing import Annotated

from fastapi import APIRouter, Header, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict

from jarvis.config import Settings
from jarvis.core import JarvisBrain
from jarvis.llm import ProviderConfigurationError, ProviderUnavailableError

router = APIRouter()
MAX_INPUT_CHARACTERS = 12_000


class ResponsesRequest(BaseModel):
    """Accepts the existing Swift request envelope; unknown fields are ignored."""

    model_config = ConfigDict(extra="ignore")

    model: str | None = None
    instructions: str | None = None
    input: str | None = None
    store: bool | None = None


def error_response(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"error": {"message": message}})


def token_is_authorized(
    presented: str | None,
    expected: Settings,
) -> bool:
    configured = expected.jarvis_client_token
    if configured is None or not configured.get_secret_value():
        return True
    return presented == configured.get_secret_value()


@router.post("/v1/responses")
async def create_response(
    payload: ResponsesRequest,
    request: Request,
    x_jarvis_client_token: Annotated[str | None, Header()] = None,
) -> JSONResponse:
    """Return a Node relay-compatible `output[].content[].output_text` envelope."""

    settings: Settings = request.app.state.settings
    brain: JarvisBrain = request.app.state.brain
    if not token_is_authorized(x_jarvis_client_token, settings):
        return error_response(401, "Unauthorized client")

    input_text = (payload.input or "").strip()
    if not input_text or len(input_text) > MAX_INPUT_CHARACTERS:
        return error_response(400, "input must contain 1 to 12000 characters")

    try:
        text = await brain.respond(input_text, payload.instructions)
    except ProviderConfigurationError:
        return error_response(503, "AI provider is not configured. Set ORCAROUTER_API_KEY.")
    except ProviderUnavailableError:
        return error_response(502, "AI upstream unavailable")

    return JSONResponse(
        status_code=200,
        content={"output": [{"content": [{"type": "output_text", "text": text}]}]},
    )
