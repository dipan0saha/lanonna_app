from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.errors import ErrorCode, InvalidInputError
from lanonna_api.db import get_connection
from lanonna_api.domain.user_errors import UserDeletedError

_PROFILE_COLUMNS = """
    firebase_uid, email, display_name, avatar_url,
    phone, birth_date, country_code, postal_code, terms_accepted_at,
    owner_onboarding_completed_at,
    notification_digest, push_notifications_enabled,
    email_digest_enabled,
    notify_gallery_enabled, notify_calendar_enabled,
    notify_registry_enabled, notify_comments_enabled,
    biometric_unlock_enabled,
    created_at, updated_at
"""


# last_seen_at is refreshed at most this often. Email and updated_at change
# only when the Firebase email claim actually changes.
LAST_SEEN_THROTTLE_MINUTES = 15

_RESOLVE_COLUMNS = _PROFILE_COLUMNS + ", deleted_at, last_seen_at"


def resolve_app_user(firebase_uid: str, email: str | None) -> dict[str, Any]:
    """Provision the app user once per request.

    Never writes a tombstoned row. Never replaces a stored email with NULL.
    ``updated_at`` moves only when the email changes. ``last_seen_at`` writes
    are throttled: a steady-state request is one plain read (no row lock),
    and the upsert runs only for a new user, a changed email or a stale
    ``last_seen_at``.
    """
    with get_connection() as conn:
        row = conn.execute(
            f"""
            SELECT {_RESOLVE_COLUMNS},
                   (last_seen_at IS NULL
                    OR last_seen_at < now() - make_interval(mins => %s)) AS seen_stale
            FROM app_users
            WHERE firebase_uid = %s
            """,
            (LAST_SEEN_THROTTLE_MINUTES, firebase_uid),
        ).fetchone()
        needs_write = row is None or (
            row["deleted_at"] is None
            and (
                row["seen_stale"]
                or (email is not None and email != row["email"])
            )
        )
        if needs_write:
            row = conn.execute(
                f"""
                INSERT INTO app_users (firebase_uid, email, last_seen_at)
                VALUES (%s, %s, now())
                ON CONFLICT (firebase_uid) DO UPDATE
                  SET email = COALESCE(EXCLUDED.email, app_users.email),
                      last_seen_at = now(),
                      updated_at = CASE
                        WHEN EXCLUDED.email IS NOT NULL
                         AND EXCLUDED.email IS DISTINCT FROM app_users.email
                        THEN now()
                        ELSE app_users.updated_at
                      END
                  WHERE app_users.deleted_at IS NULL
                    AND (
                      (
                        EXCLUDED.email IS NOT NULL
                        AND EXCLUDED.email IS DISTINCT FROM app_users.email
                      )
                      OR app_users.last_seen_at IS NULL
                      OR app_users.last_seen_at < now() - make_interval(mins => %s)
                    )
                RETURNING {_RESOLVE_COLUMNS}
                """,
                (firebase_uid, email, LAST_SEEN_THROTTLE_MINUTES),
            ).fetchone()
            if row is None:
                # A concurrent request refreshed the row first.
                row = conn.execute(
                    f"""
                    SELECT {_RESOLVE_COLUMNS}
                    FROM app_users
                    WHERE firebase_uid = %s
                    """,
                    (firebase_uid,),
                ).fetchone()
    if row is None:
        raise RuntimeError("resolve_app_user returned no row")
    result = dict(row)
    result.pop("seen_stale", None)
    if result.get("deleted_at") is not None:
        raise UserDeletedError()
    return result


def patch_profile_fields(
    firebase_uid: str,
    changes: dict[str, Any],
) -> dict[str, Any]:
    """Apply only keys present in changes; explicit null clears nullable columns."""
    if not changes:
        raise ValueError("No profile fields to update.")

    set_parts = ["updated_at = now()"]
    params: list[Any] = []

    if "display_name" in changes:
        raw = changes["display_name"]
        if raw is None or not str(raw).strip():
            raise InvalidInputError(ErrorCode.DISPLAY_NAME_REQUIRED, "Display name cannot be empty.")
        set_parts.append("display_name = %s")
        params.append(str(raw).strip())

    if "avatar_url" in changes:
        set_parts.append("avatar_url = %s")
        params.append(changes["avatar_url"])

    if "phone" in changes:
        set_parts.append("phone = %s")
        params.append(changes["phone"])

    if "birth_date" in changes:
        set_parts.append("birth_date = %s")
        params.append(changes["birth_date"])

    if "country_code" in changes:
        set_parts.append("country_code = %s")
        params.append(changes["country_code"])

    if "postal_code" in changes:
        set_parts.append("postal_code = %s")
        params.append(changes["postal_code"])

    if "accept_terms" in changes:
        if changes["accept_terms"] is True:
            set_parts.append(
                "terms_accepted_at = COALESCE(terms_accepted_at, now())"
            )
        elif changes["accept_terms"] is False:
            raise ValueError("Terms acceptance cannot be revoked.")

    if "biometric_unlock_enabled" in changes:
        set_parts.append("biometric_unlock_enabled = %s")
        params.append(bool(changes["biometric_unlock_enabled"]))

    if len(set_parts) == 1:
        raise ValueError("No profile fields to update.")

    params.append(firebase_uid)
    sql = f"""
        UPDATE app_users
        SET {", ".join(set_parts)}
        WHERE firebase_uid = %s
          AND deleted_at IS NULL
        RETURNING {_PROFILE_COLUMNS}
    """
    with get_connection() as conn:
        row = conn.execute(sql, tuple(params)).fetchone()
    if row is None:
        raise RuntimeError("patch_profile_fields returned no row")
    return dict(row)


def complete_owner_onboarding(firebase_uid: str) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE app_users
            SET owner_onboarding_completed_at = now(),
                updated_at = now()
            WHERE firebase_uid = %s
              AND deleted_at IS NULL
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
            f"""
            SELECT {_PROFILE_COLUMNS}
            FROM app_users
            WHERE firebase_uid = %s
              AND deleted_at IS NULL
            """,
            (firebase_uid,),
        ).fetchone()
    return dict(row) if row else None


def get_app_user_including_tombstone(firebase_uid: str) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT firebase_uid, deleted_at
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


def user_has_follower_membership(firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships
            WHERE firebase_uid = %s
              AND role = 'follower'
              AND removed_at IS NULL
            LIMIT 1
            """,
            (firebase_uid,),
        ).fetchone()
    return row is not None


def user_has_self_created_baby(firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1
            FROM baby_memberships m
            WHERE m.firebase_uid = %s
              AND m.role = 'owner'
              AND m.removed_at IS NULL
              AND m.joined_via = 'created'
            LIMIT 1
            """,
            (firebase_uid,),
        ).fetchone()
    return row is not None


def self_created_owner_baby_profile_id(firebase_uid: str) -> uuid.UUID | None:
    """Newest self-created owner baby profile for this user, if any."""
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT b.id
            FROM baby_memberships m
            JOIN baby_profiles b ON b.id = m.baby_profile_id
            WHERE m.firebase_uid = %s
              AND m.role = 'owner'
              AND m.removed_at IS NULL
              AND m.joined_via = 'created'
            ORDER BY b.created_at DESC
            LIMIT 1
            """,
            (firebase_uid,),
        ).fetchone()
    if row is None:
        return None
    return uuid.UUID(str(row["id"]))


def update_notification_preferences(
    firebase_uid: str,
    *,
    notification_digest: str | None = None,
    push_notifications_enabled: bool | None = None,
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
            f"""
            UPDATE app_users
            SET notification_digest = %s,
                push_notifications_enabled = %s,
                notify_gallery_enabled = %s,
                notify_calendar_enabled = %s,
                notify_registry_enabled = %s,
                notify_comments_enabled = %s,
                updated_at = now()
            WHERE firebase_uid = %s
              AND deleted_at IS NULL
            RETURNING {_PROFILE_COLUMNS}
            """,
            (
                digest,
                push,
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
