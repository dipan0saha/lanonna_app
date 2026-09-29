from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    environment: str = "dev"
    gcp_project_id: str = "lanonna-dev"

    display_bucket: str = "lanonna-dev-display"  # DISPLAY_BUCKET
    thumbnails_bucket: str = "lanonna-dev-thumbnails"  # THUMBNAILS_BUCKET

    cloud_sql_connection_name: str = ""
    db_host: str = "127.0.0.1"
    db_port: int = 5432
    db_user: str = "lanonna_app"
    db_name: str = "lanonna"
    db_password: str = ""


settings = Settings()
