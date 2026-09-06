"""FastAPI application factory for the conversation-only JARVIS Brain."""

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from jarvis import __version__
from jarvis.api.responses import router as responses_router
from jarvis.config import Settings
from jarvis.core import JarvisBrain
from jarvis.llm import LLMProvider, OrcaRouterProvider


def create_app(settings: Settings | None = None, provider: LLMProvider | None = None) -> FastAPI:
    """Build an app whose provider can be replaced in tests without network access."""

    resolved_settings = settings or Settings()
    resolved_provider = provider or OrcaRouterProvider(resolved_settings)
    app = FastAPI(title="JARVIS Brain", version=__version__)
    app.state.settings = resolved_settings
    app.state.brain = JarvisBrain(resolved_provider)
    app.include_router(responses_router)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "jarvis-brain", "version": __version__}

    @app.exception_handler(ValidationError)
    async def validation_error_handler(_, __):
        return JSONResponse(status_code=400, content={"error": {"message": "Malformed request body"}})

    return app


app = create_app()
