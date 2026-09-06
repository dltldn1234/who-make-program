"""OpenAI-compatible OrcaRouter implementation."""

from openai import APIConnectionError, APIStatusError, AsyncOpenAI

from jarvis.config import Settings

from .base import LLMProvider, ProviderConfigurationError, ProviderUnavailableError
from .models import GenerationRequest, GenerationResult

_SAFETY_INSTRUCTIONS = (
    "You are JARVIS, a personal conversational assistant. Reply naturally and concisely in Korean. "
    "This service is conversation-only: do not claim to execute device actions, shell commands, "
    "file changes, automation, or tool calls."
)


class OrcaRouterProvider(LLMProvider):
    """Text-only provider using OrcaRouter's OpenAI-compatible chat endpoint."""

    def __init__(self, settings: Settings, client: AsyncOpenAI | None = None) -> None:
        self._settings = settings
        self._client = client

    @property
    def provider_name(self) -> str:
        return "orcarouter"

    @property
    def model_name(self) -> str:
        return self._settings.jarvis_model

    async def generate(self, request: GenerationRequest) -> GenerationResult:
        api_key = self._settings.orcarouter_api_key
        if api_key is None or not api_key.get_secret_value().strip():
            raise ProviderConfigurationError("ORCAROUTER_API_KEY is not configured")

        client = self._client or AsyncOpenAI(
            api_key=api_key.get_secret_value(),
            base_url=self._settings.orcarouter_base_url,
        )
        try:
            completion = await client.chat.completions.create(
                model=self.model_name,
                messages=[
                    {"role": "system", "content": _SAFETY_INSTRUCTIONS},
                    {"role": "user", "content": request.input},
                ],
            )
        except (APIConnectionError, APIStatusError) as error:
            raise ProviderUnavailableError("OrcaRouter is unavailable") from error

        text = completion.choices[0].message.content if completion.choices else None
        if not text or not text.strip():
            raise ProviderUnavailableError("OrcaRouter returned an empty response")
        return GenerationResult(text=text.strip())
