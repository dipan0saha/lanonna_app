"""One realistic family for the aggregate-read Postgres tests.

An expecting baby with an owner, two followers and one removed member, plus
enough rows that every home/photo-detail section has more data than it shows
(more than 3 upcoming events, more than 5 pending invites, more than 4
teaser photos, more than 10 activity rows) and the removed member's votes,
likes and squishes must be excluded.
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import Any

from psycopg.types.json import Json

from lanonna_api.db import get_connection
from lanonna_api.repositories.users import resolve_app_user

OWNER = "seed-owner"
FOLLOWER = "seed-follower"
FOLLOWER2 = "seed-follower2"
FORMER = "seed-former"


def _user(conn, uid: str, name: str) -> None:
    conn.execute(
        "UPDATE app_users SET display_name = %s WHERE firebase_uid = %s",
        (name, uid),
    )


def seed_family(*, lifecycle: str = "expecting", born_days_ago: int = 2) -> dict[str, Any]:
    for uid in (OWNER, FOLLOWER, FOLLOWER2, FORMER):
        resolve_app_user(uid, f"{uid}@example.com")
    baby_id = uuid.uuid4()
    ids: dict[str, Any] = {"baby_id": baby_id, "photos": [], "events": []}
    with get_connection() as conn:
        _user(conn, OWNER, "Olivia Owner")
        _user(conn, FOLLOWER, "Aunt May")
        _user(conn, FOLLOWER2, "  ")
        _user(conn, FORMER, "Former Fred")
        conn.execute(
            """
            INSERT INTO baby_profiles (
                id, name, lifecycle_status, expected_birth_date, actual_birth_date,
                created_by_firebase_uid, avatar_url
            )
            VALUES (%s, 'Parker', %s, current_date + 40, %s, %s,
                    'avatars/babies/' || %s || '/a.webp')
            """,
            (
                baby_id,
                lifecycle,
                (date.today() - timedelta(days=born_days_ago)) if lifecycle == "born" else None,
                OWNER,
                str(baby_id),
            ),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via, created_at)
            VALUES (%s, %s, 'owner', 'created', now() - interval '90 days'),
                   (%s, %s, 'follower', 'invite', now() - interval '3 days'),
                   (%s, %s, 'follower', 'invite', now() - interval '60 days'),
                   (%s, %s, 'follower', 'invite', now() - interval '5 days')
            """,
            (baby_id, OWNER, baby_id, FOLLOWER, baby_id, FOLLOWER2, baby_id, FORMER),
        )
        # Name ideas: Milo has the most active likes; the former member's likes don't count.
        names = {n: uuid.uuid4() for n in ("Milo", "Ava", "Theo", "Robin")}
        for i, (n, sid) in enumerate(names.items()):
            conn.execute(
                """
                INSERT INTO name_suggestions (
                    id, baby_profile_id, suggested_by_firebase_uid, suggested_name, gender,
                    created_at
                )
                VALUES (%s, %s, %s, %s, %s, now() - make_interval(hours => %s))
                """,
                (sid, baby_id, FOLLOWER if i % 2 else OWNER, n,
                 "female" if n == "Ava" else "male", i),
            )
        conn.execute(
            """
            INSERT INTO name_suggestion_likes (name_suggestion_id, firebase_uid)
            VALUES (%s, %s), (%s, %s), (%s, %s), (%s, %s), (%s, %s), (%s, %s)
            """,
            (
                names["Milo"], OWNER, names["Milo"], FOLLOWER,
                names["Theo"], FORMER, names["Theo"], FOLLOWER2,
                names["Ava"], FOLLOWER2, names["Robin"], FORMER,
            ),
        )
        conn.execute(
            """
            INSERT INTO votes (baby_profile_id, firebase_uid, vote_type, gender_value, is_anonymous)
            VALUES (%s, %s, 'gender', 'male', false), (%s, %s, 'gender', 'male', true),
                   (%s, %s, 'gender', 'female', false), (%s, %s, 'gender', 'female', false)
            """,
            (baby_id, OWNER, baby_id, FOLLOWER, baby_id, FOLLOWER2, baby_id, FORMER),
        )
        conn.execute(
            """
            INSERT INTO votes (baby_profile_id, firebase_uid, vote_type, predicted_birth_date)
            VALUES (%s, %s, 'birthdate', %s), (%s, %s, 'birthdate', %s),
                   (%s, %s, 'birthdate', %s), (%s, %s, 'birthdate', %s)
            """,
            (
                baby_id, OWNER, date(2026, 11, 20),
                baby_id, FOLLOWER, date(2026, 11, 18),
                baby_id, FOLLOWER2, date(2026, 11, 20),
                baby_id, FORMER, date(2026, 11, 1),
            ),
        )
        # 5 upcoming events (home shows 3) and 2 past ones.
        for i, days in enumerate((-10, -1, 2, 5, 9, 14, 30)):
            ev = uuid.uuid4()
            ids["events"].append(ev)
            conn.execute(
                """
                INSERT INTO events (id, baby_profile_id, created_by_firebase_uid, title,
                                    starts_at, location)
                VALUES (%s, %s, %s, %s, date_trunc('minute', now()) + make_interval(days => %s), %s)
                """,
                (ev, baby_id, OWNER, f"Event {i}", days, "Home" if i % 2 else None),
            )
        # 6 ready photos with thumbs (home shows 4), one ready without a thumb, one pending.
        for i in range(8):
            pid = uuid.uuid4()
            ids["photos"].append(pid)
            status = "pending" if i == 7 else "ready"
            thumb = None if i in (1, 7) else f"thumbs/{pid}.jpg"
            conn.execute(
                """
                INSERT INTO photos (id, baby_profile_id, uploader_firebase_uid, status,
                                    display_path, thumb_path, caption, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, now() - make_interval(mins => %s))
                """,
                (pid, baby_id, OWNER if i % 3 else FOLLOWER, status,
                 f"display/{pid}.webp", thumb, f"Photo {i}", 10 * (8 - i)),
            )
        detail_photo = ids["photos"][6]
        ids["detail_photo"] = detail_photo
        conn.execute(
            """
            INSERT INTO photo_squishes (photo_id, firebase_uid)
            VALUES (%s, %s), (%s, %s), (%s, %s)
            """,
            (detail_photo, FOLLOWER, detail_photo, FORMER, detail_photo, OWNER),
        )
        conn.execute(
            """
            INSERT INTO photo_comments (photo_id, author_firebase_uid, body, created_at)
            VALUES (%s, %s, 'Lovely', now() - interval '2 hours'),
                   (%s, %s, 'So cute', now() - interval '1 hour'),
                   (%s, %s, 'Gone soon', now() - interval '30 minutes')
            """,
            (detail_photo, FOLLOWER, detail_photo, FORMER, detail_photo, OWNER),
        )
        conn.execute(
            """
            UPDATE photo_comments SET deleted_at = now()
            WHERE photo_id = %s AND body = 'Gone soon'
            """,
            (detail_photo,),
        )
        # 7 pending invitations (home shows 5) plus accepted and revoked ones.
        for i in range(9):
            status = "pending" if i < 7 else ("accepted" if i == 7 else "revoked")
            conn.execute(
                """
                INSERT INTO invitations (baby_profile_id, inviter_firebase_uid, invitee_email,
                                         role, token_hash, status, expires_at, created_at)
                VALUES (%s, %s, %s, 'follower', %s, %s, now() + interval '7 days',
                        now() - make_interval(hours => %s))
                """,
                (baby_id, OWNER, f"guest{i}@example.com", uuid.uuid4().hex, status, i),
            )
        conn.execute(
            """
            INSERT INTO registry_items (baby_profile_id, created_by_firebase_uid, name)
            VALUES (%s, %s, 'Blanket')
            """,
            (baby_id, OWNER),
        )
        for i in range(12):
            conn.execute(
                """
                INSERT INTO activity_events (baby_profile_id, actor_firebase_uid, event_type,
                                             summary, params, created_at)
                VALUES (%s, %s, 'photo_shared', 'shared a photo', %s,
                        now() - make_interval(mins => %s))
                """,
                (baby_id, OWNER if i % 2 else FOLLOWER, Json({}), i),
            )
        conn.execute(
            """
            INSERT INTO system_announcements (title, body, target_audience, priority)
            VALUES ('Welcome', 'Hello everyone', 'all', 1),
                   ('Owners only', 'Tips for owners', 'owners', 2)
            """
        )
        # The former member's membership ended; their rows stay behind and must not count.
        conn.execute(
            """
            UPDATE baby_memberships SET removed_at = now()
            WHERE baby_profile_id = %s AND firebase_uid = %s
            """,
            (baby_id, FORMER),
        )
        if lifecycle == "born":
            conn.execute(
                """
                INSERT INTO birth_announcements (baby_profile_id, created_by_firebase_uid,
                                                 first_name, last_name, weight_text, photo_id)
                VALUES (%s, %s, 'Parker', 'Lee', '7 lb 2 oz', %s)
                """,
                (baby_id, OWNER, detail_photo),
            )
        conn.execute(
            """
            INSERT INTO photo_baby_tags (photo_id, tagged_baby_profile_id)
            VALUES (%s, %s)
            """,
            (detail_photo, baby_id),
        )
    return ids
