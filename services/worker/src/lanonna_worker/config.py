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

    mailjet_api_key: str = ""  # MAILJET_API_KEY
    mailjet_api_secret: str = ""  # MAILJET_API_SECRET
    mailjet_from_email: str = "hello@lanonna.app"  # MAILJET_FROM_EMAIL
    mailjet_from_name: str = "La Nonna"  # MAILJET_FROM_NAME
    invite_deep_link_base: str = "lanonna://app"  # INVITE_DEEP_LINK_BASE


settings = Settings()
