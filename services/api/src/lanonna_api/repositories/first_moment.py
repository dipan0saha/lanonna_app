from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from lanonna_api.db import get_connection


def insert_seed_event(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    title: str,
    starts_at: datetime,
) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO events (
                baby_profile_id, created_by_firebase_uid,
                title, starts_at
            )
            VALUES (%s, %s, %s, %s)
            """,
            (baby_profile_id, firebase_uid, title, starts_at),
        )


def insert_seed_registry_item(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    name: str,
) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO registry_items (
                baby_profile_id, created_by_firebase_uid, name, priority
            )
            VALUES (%s, %s, %s, 3)
            """,
            (baby_profile_id, firebase_uid, name),
        )


def insert_seed_name_suggestion(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    suggested_name: str,
    gender: str,
) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO name_suggestions (
                baby_profile_id, suggested_by_firebase_uid,
                suggested_name, gender
            )
            VALUES (%s, %s, %s, %s)
            """,
            (baby_profile_id, firebase_uid, suggested_name, gender),
        )
