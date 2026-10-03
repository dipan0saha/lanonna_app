from __future__ import annotations

from typing import Any

from lanonna_api.db import get_connection


def upsert_app_user(firebase_uid: str, email: str | None) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO app_users (firebase_uid, email)
            VALUES (%s, %s)
            ON CONFLICT (firebase_uid) DO UPDATE
              SET email = EXCLUDED.email,
                  updated_at = now()
            RETURNING firebase_uid, email, display_name, avatar_url,
                      owner_onboarding_completed_at,
                      notification_digest, push_notifications_enabled,
                      email_digest_enabled,
                      notify_gallery_enabled, notify_calendar_enabled,
                      notify_registry_enabled, notify_comments_enabled,
                      created_at, updated_at
            """,
            (firebase_uid, email),
        ).fetchone()
    if row is None:
        raise RuntimeError("upsert_app_user returned no row")
    return dict(row)


def update_profile(
    firebase_uid: str,
    display_name: str,
    avatar_url: str | None = None,
) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE app_users
            SET display_name = %s,
                avatar_url = COALESCE(%s, avatar_url),
                updated_at = now()
            WHERE firebase_uid = %s
            RETURNING firebase_uid, email, display_name, avatar_url,
                      owner_onboarding_completed_at,
                      notification_digest, push_notifications_enabled,
                      email_digest_enabled,
                      notify_gallery_enabled, notify_calendar_enabled,
                      notify_registry_enabled, notify_comments_enabled,
                      created_at, updated_at
            """,
            (display_name.strip(), avatar_url, firebase_uid),
        ).fetchone()
    if row is None:
        raise RuntimeError("update_profile returned no row")
    return dict(row)


def complete_owner_onboarding(firebase_uid: str) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE app_users
            SET owner_onboarding_completed_at = now(),
                updated_at = now()
            WHERE firebase_uid = %s
            RETURNING firebase_uid, email, display_name, avatar_url,
                      owner_onboarding_completed_at,
                      created_at, updated_at
            """,
            (firebase_uid,),
        ).fetchone()
    if row is None:
        raise RuntimeError("complete_owner_onboarding returned no row")
    return dict(row)


def get_app_user(firebase_uid: str) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT firebase_uid, email, display_name, avatar_url,
                   owner_onboarding_completed_at,
                   notification_digest, push_notifications_enabled,
                   email_digest_enabled,
                   notify_gallery_enabled, notify_calendar_enabled,
                   notify_registry_enabled, notify_comments_enabled,
                   created_at, updated_at
            FROM app_users
            WHERE firebase_uid = %s
            """,
            (firebase_uid,),
        ).fetchone()
    return dict(row) if row else None


def user_has_baby_membership(firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships
            WHERE firebase_uid = %s
              AND removed_at IS NULL
            LIMIT 1
            """,
            (firebase_uid,),
        ).fetchone()
    return row is not None


def user_has_owner_baby(firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships
            WHERE firebase_uid = %s
              AND role = 'owner'
              AND removed_at IS NULL
            LIMIT 1
            """,
            (firebase_uid,),
        ).fetchone()
    return row is not None


def update_notification_preferences(
    firebase_uid: str,
    *,
    notification_digest: str | None = None,
    push_notifications_enabled: bool | None = None,
    email_digest_enabled: bool | None = None,
    notify_gallery_enabled: bool | None = None,
    notify_calendar_enabled: bool | None = None,
    notify_registry_enabled: bool | None = None,
    notify_comments_enabled: bool | None = None,
) -> dict[str, Any]:
    user = get_app_user(firebase_uid)
    if user is None:
        raise RuntimeError("User not found")
    digest = notification_digest or user.get("notification_digest") or "realtime"
    push = (
        push_notifications_enabled
        if push_notifications_enabled is not None
        else user.get("push_notifications_enabled", True)
    )
    email_digest = (
        email_digest_enabled
        if email_digest_enabled is not None
        else user.get("email_digest_enabled", True)
    )
    notify_gallery = (
        notify_gallery_enabled
        if notify_gallery_enabled is not None
        else user.get("notify_gallery_enabled", True)
    )
    notify_calendar = (
        notify_calendar_enabled
        if notify_calendar_enabled is not None
        else user.get("notify_calendar_enabled", True)
    )
    notify_registry = (
        notify_registry_enabled
        if notify_registry_enabled is not None
        else user.get("notify_registry_enabled", True)
    )
    notify_comments = (
        notify_comments_enabled
        if notify_comments_enabled is not None
        else user.get("notify_comments_enabled", True)
    )
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE app_users
            SET notification_digest = %s,
                push_notifications_enabled = %s,
                email_digest_enabled = %s,
                notify_gallery_enabled = %s,
                notify_calendar_enabled = %s,
                notify_registry_enabled = %s,
                notify_comments_enabled = %s,
                updated_at = now()
            WHERE firebase_uid = %s
            RETURNING firebase_uid, email, display_name, avatar_url,
                      owner_onboarding_completed_at,
                      notification_digest, push_notifications_enabled,
                      email_digest_enabled,
                      notify_gallery_enabled, notify_calendar_enabled,
                      notify_registry_enabled, notify_comments_enabled,
                      created_at, updated_at
            """,
            (
                digest,
                push,
                email_digest,
                notify_gallery,
                notify_calendar,
                notify_registry,
                notify_comments,
                firebase_uid,
            ),
        ).fetchone()
    if row is None:
        raise RuntimeError("update_notification_preferences returned no row")
    return dict(row)
