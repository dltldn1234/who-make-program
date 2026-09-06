"""Vendor-neutral interface for text-only model providers."""

from abc import ABC, abstractmethod

from .models import GenerationRequest, GenerationResult


class ProviderConfigurationError(Exception):
    """Raised when a provider has not received the configuration it requires."""


class ProviderUnavailableError(Exception):
    """Raised for provider failures without exposing upstream details or secrets."""


class LLMProvider(ABC):
    """Common interface for future OpenAI, Anthropic, Gemini, local, or Ollama providers."""

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Stable provider identifier for diagnostics."""

    @property
    @abstractmethod
    def model_name(self) -> str:
        """Configured model identifier."""

    @abstractmethod
    async def generate(self, request: GenerationRequest) -> GenerationResult:
        """Generate text only. Implementations must not invoke tools or local actions."""
