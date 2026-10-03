from __future__ import annotations

from typing import Any

from lanonna_api.db import get_connection


def upsert_device_token(firebase_uid: str, fcm_token: str, platform: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO device_tokens (firebase_uid, fcm_token, platform)
            VALUES (%s, %s, %s)
            ON CONFLICT (fcm_token) DO UPDATE
            SET firebase_uid = EXCLUDED.firebase_uid,
                platform = EXCLUDED.platform,
                updated_at = now()
            """,
            (firebase_uid, fcm_token, platform),
        )


def delete_device_token(firebase_uid: str, fcm_token: str) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            """
            DELETE FROM device_tokens
            WHERE firebase_uid = %s AND fcm_token = %s
            """,
            (firebase_uid, fcm_token),
        )
    return cur.rowcount > 0


def list_device_tokens(firebase_uid: str) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT fcm_token, platform, updated_at
            FROM device_tokens
            WHERE firebase_uid = %s
            ORDER BY updated_at DESC
            """,
            (firebase_uid,),
        ).fetchall()
    return [dict(r) for r in rows]
