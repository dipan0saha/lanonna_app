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
    # Per-instance pool. Cloud SQL allows 100 connections: worker 5 instances x 2
    # plus api 10 x 5 = 60, leaving room for migrations and admin sessions.
    db_pool_min_size: int = 1  # DB_POOL_MIN_SIZE
    db_pool_max_size: int = 2  # DB_POOL_MAX_SIZE
    db_pool_timeout_seconds: float = 30.0  # DB_POOL_TIMEOUT_SECONDS
    db_pool_max_idle_seconds: float = 300.0  # DB_POOL_MAX_IDLE_SECONDS

    mailjet_api_key: str = ""  # MAILJET_API_KEY
    mailjet_api_secret: str = ""  # MAILJET_API_SECRET
    # No placeholder default. hello@lanonna.app is not a validated Mailjet sender (#43).
    mailjet_from_email: str = ""  # MAILJET_FROM_EMAIL
    mailjet_from_name: str = "La Nonna"  # MAILJET_FROM_NAME
    # HTTPS origin for invite links, no path. Example: https://lanonna-dev.firebaseapp.com
    invite_deep_link_base: str = "https://lanonna-dev.firebaseapp.com"  # INVITE_DEEP_LINK_BASE
    # Empty uses lanonna-worker@GCP_PROJECT_ID.iam.gserviceaccount.com (export media URLs).
    gcs_signing_service_account: str = ""  # GCS_SIGNING_SERVICE_ACCOUNT

    # Must match local.pubsub_max_delivery_attempts in infra/terraform/modules/platform/pubsub.tf.
    pubsub_max_delivery_attempts: int = 12  # PUBSUB_MAX_DELIVERY_ATTEMPTS


_DEV_PROJECT_ID = "lanonna-dev"
_DEV_DISPLAY_BUCKET = "lanonna-dev-display"
_DEV_THUMBNAILS_BUCKET = "lanonna-dev-thumbnails"

# Accepted by Mailjet with HTTP 200, then never delivered (#43).
UNVALIDATED_MAILJET_FROM_EMAIL = "hello@lanonna.app"


def mailjet_sender_error(from_email: str) -> str | None:
    """Return a configuration error when the sender is missing or known-unvalidated."""
    normalized = from_email.strip().lower()
    if not normalized:
        return "MAILJET_FROM_EMAIL is required"
    if normalized == UNVALIDATED_MAILJET_FROM_EMAIL:
        return (
            "MAILJET_FROM_EMAIL hello@lanonna.app is not a validated Mailjet sender"
        )
    return None


def invite_link_base_error(base: str, *, environment: str) -> str | None:
    """Invite mail must use an https origin so mail clients can open it."""
    normalized = base.strip().rstrip("/")
    if not normalized.startswith("https://"):
        return (
            "INVITE_DEEP_LINK_BASE must be an https origin "
            "(for example https://PROJECT_ID.firebaseapp.com)"
        )
    if environment.lower() != "dev" and "lanonna-dev" in normalized:
        return "INVITE_DEEP_LINK_BASE must not use the dev host outside dev"
    return None


def validate_worker_settings(cfg: Settings | None = None) -> None:
    """Refuse to start with a missing sender, or with dev defaults outside dev."""
    cfg = cfg or settings
    errors: list[str] = []
    sender_error = mailjet_sender_error(cfg.mailjet_from_email)
    if sender_error:
        errors.append(sender_error)
    link_error = invite_link_base_error(
        cfg.invite_deep_link_base, environment=cfg.environment
    )
    if link_error:
        errors.append(link_error)
    if cfg.environment.lower() != "dev":
        if cfg.gcp_project_id == _DEV_PROJECT_ID:
            errors.append("GCP_PROJECT_ID must not be the dev default outside dev")
        if cfg.display_bucket == _DEV_DISPLAY_BUCKET:
            errors.append("DISPLAY_BUCKET must not be the dev default outside dev")
        if cfg.thumbnails_bucket == _DEV_THUMBNAILS_BUCKET:
            errors.append("THUMBNAILS_BUCKET must not be the dev default outside dev")
        expected_display = f"{cfg.gcp_project_id}-display"
        expected_thumbs = f"{cfg.gcp_project_id}-thumbnails"
        if cfg.display_bucket != expected_display:
            errors.append(
                f"DISPLAY_BUCKET must be {expected_display} (got {cfg.display_bucket})"
            )
        if cfg.thumbnails_bucket != expected_thumbs:
            errors.append(
                f"THUMBNAILS_BUCKET must be {expected_thumbs} (got {cfg.thumbnails_bucket})"
            )
    if errors:
        raise RuntimeError("Invalid worker configuration: " + "; ".join(errors))


settings = Settings()
