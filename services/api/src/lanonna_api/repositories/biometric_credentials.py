"""SQL for device-bound biometric sign-in credentials and their challenges."""

from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from lanonna_api.db import get_connection

CHALLENGE_TTL = timedelta(seconds=120)
NONCE_BYTES = 32


def register_credential(
    firebase_uid: str,
    device_id: str,
    public_key_pem: str,
    algorithm: str,
) -> dict[str, Any]:
    """Store a new public key; the account's previous key on this install is revoked."""
    with get_connection() as conn:
        with conn.transaction():
            conn.execute(
                """
                UPDATE biometric_credentials
                SET revoked_at = now()
                WHERE firebase_uid = %s
                  AND device_id = %s
                  AND revoked_at IS NULL
                """,
                (firebase_uid, device_id),
            )
            row = conn.execute(
                """
                INSERT INTO biometric_credentials (
                    firebase_uid, device_id, public_key_pem, algorithm
                )
                VALUES (%s, %s, %s, %s)
                RETURNING id, created_at
                """,
                (firebase_uid, device_id, public_key_pem, algorithm),
            ).fetchone()
    return {"id": str(row["id"]), "created_at": row["created_at"].isoformat()}


def revoke_all_for_user(firebase_uid: str, *, conn: Any | None = None) -> int:
    sql = """
        UPDATE biometric_credentials
        SET revoked_at = now()
        WHERE firebase_uid = %s
          AND revoked_at IS NULL
    """
    if conn is not None:
        return conn.execute(sql, (firebase_uid,)).rowcount or 0
    with get_connection() as own:
        return own.execute(sql, (firebase_uid,)).rowcount or 0


def revoke_credential(credential_id: uuid.UUID) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE biometric_credentials
            SET revoked_at = now()
            WHERE id = %s
              AND revoked_at IS NULL
            """,
            (credential_id,),
        )


def get_live_credential(credential_id: uuid.UUID) -> dict[str, Any] | None:
    """The credential when it is not revoked and its account is not tombstoned."""
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT c.id, c.firebase_uid, c.public_key_pem, c.algorithm, c.created_at
            FROM biometric_credentials c
            JOIN app_users u ON u.firebase_uid = c.firebase_uid
            WHERE c.id = %s
              AND c.revoked_at IS NULL
              AND u.deleted_at IS NULL
            """,
            (credential_id,),
        ).fetchone()
    return dict(row) if row else None


def create_challenge(credential_id: uuid.UUID) -> dict[str, Any]:
    """Issue a fresh nonce; any earlier challenge for this credential stops working."""
    nonce = secrets.token_urlsafe(NONCE_BYTES)
    expires_at = datetime.now(timezone.utc) + CHALLENGE_TTL
    with get_connection() as conn:
        with conn.transaction():
            conn.execute(
                "DELETE FROM biometric_sign_in_challenges WHERE credential_id = %s",
                (credential_id,),
            )
            row = conn.execute(
                """
                INSERT INTO biometric_sign_in_challenges (credential_id, nonce, expires_at)
                VALUES (%s, %s, %s)
                RETURNING id
                """,
                (credential_id, nonce, expires_at),
            ).fetchone()
    return {
        "challenge_id": str(row["id"]),
        "nonce": nonce,
        "expires_at": expires_at.isoformat(),
    }


def consume_challenge(challenge_id: uuid.UUID, credential_id: uuid.UUID) -> str | None:
    """Atomically take the nonce of a live challenge; ``None`` when expired, used or unknown.

    The row is deleted in the same statement, so concurrent requests cannot both
    receive the nonce and a challenge verifies at most once, pass or fail.
    """
    with get_connection() as conn:
        row = conn.execute(
            """
            DELETE FROM biometric_sign_in_challenges
            WHERE id = %s
              AND credential_id = %s
            RETURNING nonce, expires_at > now() AS live
            """,
            (challenge_id, credential_id),
        ).fetchone()
    if row is None or not row["live"]:
        return None
    return row["nonce"]


def mark_credential_used(credential_id: uuid.UUID) -> None:
    with get_connection() as conn:
        conn.execute(
            "UPDATE biometric_credentials SET last_used_at = now() WHERE id = %s",
            (credential_id,),
        )
