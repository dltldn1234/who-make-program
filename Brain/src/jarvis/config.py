"""Runtime configuration. Secrets are deliberately represented as SecretStr."""

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment-backed Brain settings with safe defaults for local startup."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    orcarouter_api_key: SecretStr | None = None
    orcarouter_base_url: str = "https://api.orcarouter.ai/v1"
    jarvis_model: str = "orcarouter/auto"
    jarvis_client_token: SecretStr | None = None
