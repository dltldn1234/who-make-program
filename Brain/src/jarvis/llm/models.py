"""Small provider-neutral data models."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class GenerationRequest:
    input: str
    instructions: str | None = None


@dataclass(frozen=True, slots=True)
class GenerationResult:
    text: str
