from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.db import get_connection
from lanonna_api.repositories.active_participants import active_participant_join


def home_summary_counts(baby_profile_id: uuid.UUID) -> dict[str, Any]:
    """Every count and flag the home summary shows, in one round trip.

    Family insight: name idea count, gender votes (total and per side) and the
    most-guessed birth date, counting active participants only. Getting
    started: whether the baby has any registry item, invitation, follower,
    photo or event (``EXISTS``, so nothing is counted that is only tested).
    """
    with get_connection() as conn:
        row = conn.execute(
            f"""
            SELECT
                (SELECT COUNT(*)::int FROM name_suggestions n
                 WHERE n.baby_profile_id = %(baby)s) AS name_suggestion_count,
                g.vote_count,
                g.male_votes,
                g.female_votes,
                (
                    SELECT v.predicted_birth_date
                    FROM votes v
                    {active_participant_join("v.firebase_uid", "v.baby_profile_id")}
                    WHERE v.baby_profile_id = %(baby)s
                      AND v.vote_type = 'birthdate'
                      AND v.predicted_birth_date IS NOT NULL
                    GROUP BY v.predicted_birth_date
                    ORDER BY COUNT(*) DESC, v.predicted_birth_date ASC
                    LIMIT 1
                ) AS top_birthdate_guess,
                EXISTS (SELECT 1 FROM registry_items r
                        WHERE r.baby_profile_id = %(baby)s) AS has_registry_item,
                EXISTS (SELECT 1 FROM invitations i
                        WHERE i.baby_profile_id = %(baby)s) AS has_invitation,
                EXISTS (SELECT 1 FROM baby_memberships m
                        WHERE m.baby_profile_id = %(baby)s
                          AND m.role = 'follower'
                          AND m.removed_at IS NULL) AS has_follower,
                EXISTS (SELECT 1 FROM photos p
                        WHERE p.baby_profile_id = %(baby)s) AS has_photo,
                EXISTS (SELECT 1 FROM events e
                        WHERE e.baby_profile_id = %(baby)s) AS has_event
            FROM (
                SELECT
                    COUNT(*)::int AS vote_count,
                    COUNT(*) FILTER (WHERE v.gender_value = 'male')::int AS male_votes,
                    COUNT(*) FILTER (WHERE v.gender_value = 'female')::int AS female_votes
                FROM votes v
                {active_participant_join("v.firebase_uid", "v.baby_profile_id")}
                WHERE v.baby_profile_id = %(baby)s AND v.vote_type = 'gender'
            ) g
            """,
            {"baby": baby_profile_id},
        ).fetchone()
    return dict(row)


def list_new_followers(
    baby_profile_id: uuid.UUID,
    since_days: int = 30,
    limit: int = 5,
) -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                m.firebase_uid,
                m.created_at AS joined_at,
                NULLIF(TRIM(u.display_name), '') AS display_name
            FROM baby_memberships m
            JOIN app_users u ON u.firebase_uid = m.firebase_uid
            WHERE m.baby_profile_id = %s
              AND m.role = 'follower'
              AND m.removed_at IS NULL
              AND m.created_at >= now() - make_interval(days => %s)
            ORDER BY m.created_at DESC
            LIMIT %s
            """,
            (baby_profile_id, since_days, limit),
        ).fetchall()
    return [dict(r) for r in rows]
