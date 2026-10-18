from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    environment: str = "dev"  # env: ENVIRONMENT
    gcp_project_id: str = "lanonna-dev"
    # Comma-separated Firebase ID token `aud` values; empty = [gcp_project_id] only.
    firebase_audiences: str = ""

    def firebase_audience_allowlist(self) -> frozenset[str]:
        raw = self.firebase_audiences.strip()
        if not raw:
            return frozenset({self.gcp_project_id})
        return frozenset(part.strip() for part in raw.split(",") if part.strip())

    cloud_sql_connection_name: str = ""  # CLOUD_SQL_CONNECTION_NAME
    db_host: str = "127.0.0.1"
    db_port: int = 5432
    db_user: str = "lanonna_app"
    db_name: str = "lanonna"
    db_password: str = ""
    # Per-instance connection pool (db.py). Cloud SQL allows 100 connections:
    # api max 10 instances x 5 + worker max 5 instances x 2 = 60, leaving room
    # for a rolling deploy, migrations and the proxy.
    db_pool_min_size: int = 1  # DB_POOL_MIN_SIZE
    db_pool_max_size: int = 5  # DB_POOL_MAX_SIZE
    db_pool_timeout_seconds: float = 10.0  # DB_POOL_TIMEOUT_SECONDS: wait for a free connection
    db_pool_max_idle_seconds: float = 300.0  # DB_POOL_MAX_IDLE_SECONDS: close extra idle connections

    display_bucket: str = "lanonna-dev-display"
    thumbnails_bucket: str = "lanonna-dev-thumbnails"  # THUMBNAILS_BUCKET
    display_allowed_content_types: tuple[str, ...] = ("image/jpeg", "image/webp")
    gcs_signing_service_account: str = "lanonna-api@lanonna-dev.iam.gserviceaccount.com"

    pubsub_topic_commands: str = "lanonna-async-commands"  # PUBSUB_TOPIC_COMMANDS
    # When true, API logs invite publish instead of calling Pub/Sub (local dev).
    invite_email_publish_disabled: bool = False  # INVITE_EMAIL_PUBLISH_DISABLED
    notify_publish_disabled: bool = False  # NOTIFY_PUBLISH_DISABLED

    admin_api_key: str = ""  # ADMIN_API_KEY — ops CRUD for system announcements
    app_check_enforce: bool = False  # APP_CHECK_ENFORCE — reject missing/invalid App Check (dev deploy: see deploy.sh TEMP note)
    # Comma-separated browser origins; empty = no CORS (mobile-only default).
    cors_allow_origins: str = ""  # CORS_ALLOW_ORIGINS

    def cors_allow_origins_list(self) -> list[str]:
        raw = self.cors_allow_origins.strip()
        if not raw:
            return []
        return [part.strip() for part in raw.split(",") if part.strip()]


settings = Settings()
