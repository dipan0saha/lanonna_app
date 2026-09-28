from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    environment: str = "dev"  # env: ENVIRONMENT
    gcp_project_id: str = "lanonna-dev"
    # Comma-separated; empty = accept default Firebase project only.
    firebase_audiences: str = ""

    cloud_sql_connection_name: str = ""  # CLOUD_SQL_CONNECTION_NAME
    db_host: str = "127.0.0.1"
    db_port: int = 5432
    db_user: str = "lanonna_app"
    db_name: str = "lanonna"
    db_password: str = ""

    display_bucket: str = "lanonna-dev-display"
    display_allowed_content_types: tuple[str, ...] = ("image/jpeg", "image/webp")
    gcs_signing_service_account: str = "lanonna-api@lanonna-dev.iam.gserviceaccount.com"


settings = Settings()
