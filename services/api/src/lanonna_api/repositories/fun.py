from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from lanonna_api.db import get_connection


def count_gender_votes(baby_profile_id: uuid.UUID) -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*)::int AS count
            FROM votes
            WHERE baby_profile_id = %s AND vote_type = 'gender'
            """,
            (baby_profile_id,),
        ).fetchone()
    return int(row["count"]) if row else 0


def list_name_suggestions(baby_profile_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                n.id, n.suggested_name, n.gender, n.suggested_by_firebase_uid,
                n.created_at,
                u.display_name AS author_display_name,
                u.email AS author_email,
                (SELECT COUNT(*)::int FROM name_suggestion_likes l
                 WHERE l.name_suggestion_id = n.id) AS like_count
            FROM name_suggestions n
            JOIN app_users u ON u.firebase_uid = n.suggested_by_firebase_uid
            WHERE n.baby_profile_id = %s
            ORDER BY like_count DESC, n.created_at DESC
            """,
            (baby_profile_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def find_name_suggestion_case_insensitive(
    baby_profile_id: uuid.UUID,
    suggested_name: str,
    gender: str,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, suggested_name, gender
            FROM name_suggestions
            WHERE baby_profile_id = %s
              AND gender = %s
              AND lower(suggested_name) = lower(%s)
            LIMIT 1
            """,
            (baby_profile_id, gender, suggested_name.strip()),
        ).fetchone()
    return dict(row) if row else None


def insert_name_suggestion(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    suggested_name: str,
    gender: str,
) -> dict[str, Any]:
    suggestion_id = uuid.uuid4()
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO name_suggestions (
                id, baby_profile_id, suggested_by_firebase_uid,
                suggested_name, gender
            )
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id, suggested_name, gender, created_at
            """,
            (suggestion_id, baby_profile_id, firebase_uid, suggested_name.strip(), gender),
        ).fetchone()
    if row is None:
        raise RuntimeError("insert_name_suggestion failed")
    return dict(row)


def count_suggestions_by_author_gender(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    gender: str,
) -> int:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*)::int AS count
            FROM name_suggestions
            WHERE baby_profile_id = %s
              AND suggested_by_firebase_uid = %s
              AND gender = %s
            """,
            (baby_profile_id, firebase_uid, gender),
        ).fetchone()
    return int(row["count"]) if row else 0


def delete_name_suggestion(
    baby_profile_id: uuid.UUID,
    suggestion_id: uuid.UUID,
) -> bool:
    with get_connection() as conn:
        cur = conn.execute(
            """
            DELETE FROM name_suggestions
            WHERE id = %s AND baby_profile_id = %s
            """,
            (suggestion_id, baby_profile_id),
        )
    return cur.rowcount > 0


def get_name_suggestion(
    baby_profile_id: uuid.UUID,
    suggestion_id: uuid.UUID,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, suggested_name, gender, suggested_by_firebase_uid
            FROM name_suggestions
            WHERE id = %s AND baby_profile_id = %s
            """,
            (suggestion_id, baby_profile_id),
        ).fetchone()
    return dict(row) if row else None


def caller_liked_suggestion_ids(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> dict[str, uuid.UUID | None]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT n.gender, l.name_suggestion_id
            FROM name_suggestion_likes l
            JOIN name_suggestions n ON n.id = l.name_suggestion_id
            WHERE n.baby_profile_id = %s AND l.firebase_uid = %s
            """,
            (baby_profile_id, firebase_uid),
        ).fetchall()
    out: dict[str, uuid.UUID | None] = {"male": None, "female": None}
    for row in rows:
        g = row["gender"]
        if g in out:
            out[g] = row["name_suggestion_id"]
    return out


def remove_likes_for_user_gender(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    gender: str,
    conn=None,
) -> None:
    def _run(connection):
        connection.execute(
            """
            DELETE FROM name_suggestion_likes l
            USING name_suggestions n
            WHERE l.name_suggestion_id = n.id
              AND n.baby_profile_id = %s
              AND n.gender = %s
              AND l.firebase_uid = %s
            """,
            (baby_profile_id, gender, firebase_uid),
        )

    if conn is not None:
        _run(conn)
    else:
        with get_connection() as connection:
            _run(connection)


def add_like(suggestion_id: uuid.UUID, firebase_uid: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO name_suggestion_likes (name_suggestion_id, firebase_uid)
            VALUES (%s, %s)
            ON CONFLICT DO NOTHING
            """,
            (suggestion_id, firebase_uid),
        )


def remove_like(suggestion_id: uuid.UUID, firebase_uid: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """
            DELETE FROM name_suggestion_likes
            WHERE name_suggestion_id = %s AND firebase_uid = %s
            """,
            (suggestion_id, firebase_uid),
        )


def user_has_like(suggestion_id: uuid.UUID, firebase_uid: str) -> bool:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT 1 FROM name_suggestion_likes
            WHERE name_suggestion_id = %s AND firebase_uid = %s
            """,
            (suggestion_id, firebase_uid),
        ).fetchone()
    return row is not None


def upsert_gender_vote(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    gender_value: str,
    is_anonymous: bool,
) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO votes (
                baby_profile_id, firebase_uid, vote_type,
                gender_value, is_anonymous
            )
            VALUES (%s, %s, 'gender', %s, %s)
            ON CONFLICT (baby_profile_id, firebase_uid, vote_type) DO UPDATE
              SET gender_value = EXCLUDED.gender_value,
                  is_anonymous = EXCLUDED.is_anonymous,
                  updated_at = now()
            RETURNING id, gender_value, is_anonymous, updated_at
            """,
            (baby_profile_id, firebase_uid, gender_value, is_anonymous),
        ).fetchone()
    if row is None:
        raise RuntimeError("upsert_gender_vote failed")
    return dict(row)


def upsert_birthdate_vote(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
    predicted_birth_date: date,
    is_anonymous: bool,
) -> dict[str, Any]:
    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO votes (
                baby_profile_id, firebase_uid, vote_type,
                predicted_birth_date, is_anonymous
            )
            VALUES (%s, %s, 'birthdate', %s, %s)
            ON CONFLICT (baby_profile_id, firebase_uid, vote_type) DO UPDATE
              SET predicted_birth_date = EXCLUDED.predicted_birth_date,
                  is_anonymous = EXCLUDED.is_anonymous,
                  updated_at = now()
            RETURNING id, predicted_birth_date, is_anonymous, updated_at
            """,
            (baby_profile_id, firebase_uid, predicted_birth_date, is_anonymous),
        ).fetchone()
    if row is None:
        raise RuntimeError("upsert_birthdate_vote failed")
    return dict(row)


def get_caller_votes(
    baby_profile_id: uuid.UUID,
    firebase_uid: str,
) -> dict[str, Any]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT vote_type, gender_value, predicted_birth_date, is_anonymous
            FROM votes
            WHERE baby_profile_id = %s AND firebase_uid = %s
            """,
            (baby_profile_id, firebase_uid),
        ).fetchall()
    out: dict[str, Any] = {}
    for row in rows:
        if row["vote_type"] == "gender":
            out["gender"] = row["gender_value"]
            out["is_anonymous"] = row["is_anonymous"]
        elif row["vote_type"] == "birthdate":
            out["birthdate"] = row["predicted_birth_date"]
            if "is_anonymous" not in out:
                out["is_anonymous"] = row["is_anonymous"]
    return out


def gender_vote_totals(baby_profile_id: uuid.UUID) -> dict[str, int]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT gender_value, COUNT(*)::int AS count
            FROM votes
            WHERE baby_profile_id = %s AND vote_type = 'gender'
            GROUP BY gender_value
            """,
            (baby_profile_id,),
        ).fetchall()
    out = {"male": 0, "female": 0}
    for row in rows:
        if row["gender_value"]:
            out[row["gender_value"]] = row["count"]
    return out


def list_gender_voters(baby_profile_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT v.gender_value, v.is_anonymous, v.firebase_uid,
                   u.display_name, u.email
            FROM votes v
            JOIN app_users u ON u.firebase_uid = v.firebase_uid
            WHERE v.baby_profile_id = %s AND v.vote_type = 'gender'
            ORDER BY v.created_at ASC
            """,
            (baby_profile_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def birthdate_vote_histogram(baby_profile_id: uuid.UUID) -> list[dict[str, Any]]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT predicted_birth_date, COUNT(*)::int AS count
            FROM votes
            WHERE baby_profile_id = %s
              AND vote_type = 'birthdate'
              AND predicted_birth_date IS NOT NULL
            GROUP BY predicted_birth_date
            ORDER BY count DESC, predicted_birth_date ASC
            """,
            (baby_profile_id,),
        ).fetchall()
    return [dict(r) for r in rows]
