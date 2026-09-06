"""The Brain delegates conversation generation and normalizes its text result."""

from jarvis.llm import GenerationRequest, LLMProvider


class JarvisBrain:
    """Conversation-only orchestration boundary for the API layer."""

    def __init__(self, provider: LLMProvider) -> None:
        self._provider = provider

    async def respond(self, input_text: str, instructions: str | None = None) -> str:
        result = await self._provider.generate(
            GenerationRequest(input=input_text, instructions=instructions)
        )
        return result.text.strip()
