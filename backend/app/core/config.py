from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Paramètres techniques d'infrastructure.

    Les paramètres métier (points, récompenses, seuils, rappels...) sont stockés
    en base et modifiables depuis les interfaces d'administration.
    """

    model_config = SettingsConfigDict(env_prefix="LAVPRO_", env_file=".env", extra="ignore")

    app_name: str = "Lavpro API"
    api_prefix: str = "/api/v1"
    database_url: str = "sqlite:///./lavpro.db"
    secret_key: str = "dev-secret-change-me"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7
    cors_origins: list[str] = ["http://localhost:4200"]
    superadmin_email: str | None = None
    superadmin_password: str | None = None
    weather_api_url: str = "https://api.open-meteo.com/v1/forecast"
    fcm_server_key: str | None = None
    upload_dir: str = "uploads"


@lru_cache
def get_settings() -> Settings:
    return Settings()
