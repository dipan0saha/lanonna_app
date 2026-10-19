from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from lanonna_api.db import get_connection

CHALLENGE_TTL_SECONDS = 120
NONCE_BYTES = 32


def register_credential(
    firebase_uid: str,
    device_id: str,
    public_key_pem: str,
    algorithm: str,
) -> dict[str, Any]:
    device_id = device_id.strip()
    if not device_id:
        raise ValueError("device_id required")
    public_key_pem = public_key_pem.strip()
    if not public_key_pem:
        raise ValueError("public_key_pem required")
    algorithm = algorithm.strip()
    if not algorithm:
        raise ValueError("algorithm required")
    now = datetime.now(timezone.utc)
    credential_id = uuid.uuid4()
    with get_connection() as conn:
        with conn.transaction():
            conn.execute(
                """
                UPDATE biometric_credentials
                SET revoked_at = %s
                WHERE device_id = %s
                  AND revoked_at IS NULL
                """,
                (now, device_id),
            )
            conn.execute(
                """
                INSERT INTO biometric_credentials (
                    id, firebase_uid, device_id, public_key_pem, algorithm, created_at
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    credential_id,
                    firebase_uid,
                    device_id,
                    public_key_pem,
                    algorithm,
                    now,
                ),
            )
    return {
        "id": str(credential_id),
        "created_at": now.isoformat(),
    }


def revoke_credential(firebase_uid: str, credential_id: str) -> bool:
    now = datetime.now(timezone.utc)
    with get_connection() as conn:
        row = conn.execute(
            """
            UPDATE biometric_credentials
            SET revoked_at = %s
            WHERE id = %s
              AND firebase_uid = %s
              AND revoked_at IS NULL
            RETURNING id
            """,
            (now, credential_id, firebase_uid),
        ).fetchone()
    return row is not None


def revoke_all_for_user(firebase_uid: str) -> int:
    now = datetime.now(timezone.utc)
    with get_connection() as conn:
        result = conn.execute(
            """
            UPDATE biometric_credentials
            SET revoked_at = %s
            WHERE firebase_uid = %s
              AND revoked_at IS NULL
            """,
            (now, firebase_uid),
        )
    return result.rowcount or 0


def get_active_credential(credential_id: str) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT c.id,
                   c.firebase_uid,
                   c.device_id,
                   c.public_key_pem,
                   c.algorithm,
                   c.created_at,
                   c.revoked_at,
                   u.deleted_at
            FROM biometric_credentials c
            JOIN app_users u ON u.firebase_uid = c.firebase_uid
            WHERE c.id = %s
            """,
            (credential_id,),
        ).fetchone()
    return dict(row) if row else None


def create_challenge(credential_id: str) -> dict[str, Any]:
    nonce = secrets.token_urlsafe(NONCE_BYTES)
    challenge_id = uuid.uuid4()
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=CHALLENGE_TTL_SECONDS)
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO biometric_sign_in_challenges (
                id, credential_id, nonce, expires_at
            )
            VALUES (%s, %s, %s, %s)
            """,
            (challenge_id, credential_id, nonce, expires_at),
        )
    return {
        "challenge_id": str(challenge_id),
        "nonce": nonce,
        "expires_at": expires_at.isoformat(),
    }


def consume_challenge(challenge_id: str, credential_id: str) -> str | None:
    """Mark challenge used and return nonce if valid."""
    now = datetime.now(timezone.utc)
    with get_connection() as conn:
        with conn.transaction():
            row = conn.execute(
                """
                SELECT nonce, expires_at, used_at
                FROM biometric_sign_in_challenges
                WHERE id = %s
                  AND credential_id = %s
                FOR UPDATE
                """,
                (challenge_id, credential_id),
            ).fetchone()
            if row is None:
                return None
            if row["used_at"] is not None:
                return None
            if row["expires_at"] < now:
                return None
            conn.execute(
                """
                UPDATE biometric_sign_in_challenges
                SET used_at = %s
                WHERE id = %s
                """,
                (now, challenge_id),
            )
            return row["nonce"]


def mark_credential_used(credential_id: str) -> None:
    now = datetime.now(timezone.utc)
    with get_connection() as conn:
        conn.execute(
            """
            UPDATE biometric_credentials
            SET last_used_at = %s
            WHERE id = %s
            """,
            (now, credential_id),
        )
