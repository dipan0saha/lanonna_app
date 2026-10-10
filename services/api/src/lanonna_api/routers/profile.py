from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from lanonna_api.auth import current_user
from lanonna_api.domain.avatar_urls import normalize_avatar_for_storage, signed_avatar_url
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.domain.account import build_account_extensions
from lanonna_api.domain.account_delete import delete_account, delete_account_eligibility
from lanonna_api.repositories.babies import list_babies_for_user
from lanonna_api.repositories.users import (
    patch_profile_fields,
    update_notification_preferences,
    upsert_app_user,
)
from pydantic import BaseModel
from lanonna_api.schemas.babies import baby_summary_from_row
from lanonna_api.schemas.profile import ProfileResponse, ProfileUpdateRequest

router = APIRouter(prefix="/v1", tags=["profile"])


def _to_profile_response(row: dict[str, Any]) -> ProfileResponse:
    birth = row.get("birth_date")
    terms = row.get("terms_accepted_at")
    return ProfileResponse(
        firebase_uid=row["firebase_uid"],
        email=row.get("email"),
        display_name=row.get("display_name"),
        avatar_url=signed_avatar_url(row.get("avatar_url")),
        phone=row.get("phone"),
        birth_date=birth,
        country_code=row.get("country_code"),
        postal_code=row.get("postal_code"),
        terms_accepted_at=terms,
        owner_onboarding_completed=row.get("owner_onboarding_completed_at") is not None,
        created_at=row["created_at"].isoformat(),
        updated_at=row["updated_at"].isoformat(),
    )


@router.get("/me/account")
def get_account(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    row = upsert_app_user(user["uid"], user.get("email"))
    babies = list_babies_for_user(user["uid"])
    extensions = build_account_extensions(user["uid"])
    return {
        "profile": _to_profile_response(row).model_dump(),
        "babies": [
            baby_summary_from_row(b).model_dump(mode="json") for b in babies
        ],
        "engagement": extensions["engagement"],
        "storage_usage": extensions["storage_usage"],
    }


@router.patch("/profile", response_model=ProfileResponse)
def patch_profile(
    body: ProfileUpdateRequest,
    user: dict[str, Any] = Depends(current_user),
) -> ProfileResponse:
    upsert_app_user(user["uid"], user.get("email"))
    changes = body.model_dump(exclude_unset=True)
    if "avatar_url" in changes and changes["avatar_url"] is not None:
        try:
            changes["avatar_url"] = normalize_avatar_for_storage(changes["avatar_url"])
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(exc),
            ) from exc
    try:
        row = patch_profile_fields(user["uid"], changes)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except RuntimeError as exc:
        raise map_domain_errors(exc) from exc
    return _to_profile_response(row)


class NotificationPreferencesUpdate(BaseModel):
    notification_digest: str | None = None
    push_notifications_enabled: bool | None = None
    email_digest_enabled: bool | None = None
    notify_gallery_enabled: bool | None = None
    notify_calendar_enabled: bool | None = None
    notify_registry_enabled: bool | None = None
    notify_comments_enabled: bool | None = None


def _notification_preferences_payload(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "notification_digest": row.get("notification_digest") or "realtime",
        "push_notifications_enabled": bool(row.get("push_notifications_enabled", True)),
        "email_digest_enabled": bool(row.get("email_digest_enabled", True)),
        "notify_gallery_enabled": bool(row.get("notify_gallery_enabled", True)),
        "notify_calendar_enabled": bool(row.get("notify_calendar_enabled", True)),
        "notify_registry_enabled": bool(row.get("notify_registry_enabled", True)),
        "notify_comments_enabled": bool(row.get("notify_comments_enabled", True)),
    }


@router.get("/me/notification-preferences")
def get_notification_preferences(
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    row = upsert_app_user(user["uid"], user.get("email"))
    return _notification_preferences_payload(row)


@router.patch("/me/notification-preferences")
def patch_notification_preferences(
    body: NotificationPreferencesUpdate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    if body.notification_digest is not None and body.notification_digest not in (
        "realtime",
        "daily",
        "weekly",
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid notification_digest",
        )
    row = update_notification_preferences(
        user["uid"],
        notification_digest=body.notification_digest,
        push_notifications_enabled=body.push_notifications_enabled,
        email_digest_enabled=body.email_digest_enabled,
        notify_gallery_enabled=body.notify_gallery_enabled,
        notify_calendar_enabled=body.notify_calendar_enabled,
        notify_registry_enabled=body.notify_registry_enabled,
        notify_comments_enabled=body.notify_comments_enabled,
    )
    return _notification_preferences_payload(row)


class DeleteAccountBody(BaseModel):
    confirm: bool = False


@router.get("/me/delete-account/eligibility")
def get_delete_account_eligibility(
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    return delete_account_eligibility(user["uid"])


@router.post("/me/delete-account")
def post_delete_account(
    body: DeleteAccountBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, str]:
    if not body.confirm:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="confirm must be true",
        )
    try:
        delete_account(user["uid"])
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    except RuntimeError as exc:
        raise map_domain_errors(exc) from exc
    return {"status": "deleted"}
