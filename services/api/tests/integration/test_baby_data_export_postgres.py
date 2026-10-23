"""Baby export against real Postgres (#24).

Mocks cannot see a wrong column name. This seeds one row in every covered
table and checks the version-2 document.
"""

from __future__ import annotations

import json
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.users import resolve_app_user

_WORKER_SRC = Path(__file__).resolve().parents[4] / "services" / "worker" / "src"
if str(_WORKER_SRC) not in sys.path:
    sys.path.insert(0, str(_WORKER_SRC))

from lanonna_worker.export.build import build_baby_export_json  # noqa: E402
from lanonna_worker.export.coverage import (  # noqa: E402
    COVERED_TABLES,
    unclassified_tables,
    discover_baby_graph_tables,
)

pytestmark = pytest.mark.integration

_OWNER = "uid-export-owner-aaa"
_FOLLOWER = "uid-export-follower-bbb"
_REMOVED = "uid-export-removed-ccc"
_OTHER = "uid-export-other-ddd"
_OWNER_EMAIL = "owner.secret@example.com"
_FOLLOWER_EMAIL = "follower.secret@example.com"
_REMOVED_EMAIL = "removed.secret@example.com"
_OTHER_EMAIL = "other.secret@example.com"
_PENDING_EMAIL = "guest.pending@example.com"


def _sign(bucket: str, path: str) -> str:
    return f"https://signed.example/{bucket}/{path}"


def _insert_user(uid: str, email: str, display_name: str) -> None:
    resolve_app_user(uid, email)
    with get_connection() as conn:
        conn.execute(
            "UPDATE app_users SET display_name = %s WHERE firebase_uid = %s",
            (display_name, uid),
        )


def test_export_covers_baby_graph_tables():
    with get_connection() as conn:
        discovered = discover_baby_graph_tables(conn)
    missing = unclassified_tables(discovered)
    assert not missing, f"baby-scoped tables missing from the export manifest: {sorted(missing)}"
    assert COVERED_TABLES <= discovered


def test_export_includes_family_content_without_uids_or_member_emails():
    _insert_user(_OWNER, _OWNER_EMAIL, "Owner Ada")
    _insert_user(_FOLLOWER, _FOLLOWER_EMAIL, "Follower Bea")
    _insert_user(_REMOVED, _REMOVED_EMAIL, "Removed Cam")
    _insert_user(_OTHER, _OTHER_EMAIL, "Other Dana")

    baby_id = uuid.uuid4()
    other_baby_id = uuid.uuid4()
    visible_baby_id = uuid.uuid4()
    now = datetime(2026, 6, 1, tzinfo=timezone.utc)
    token_hash = "a" * 64
    delivery_token = "plain-invite-token-must-not-leak"

    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (
                id, name, expected_birth_date, gender, lifecycle_status,
                created_by_firebase_uid, avatar_url,
                registry_shipping_line1, registry_shipping_city,
                registry_shipping_postal_code, registry_shipping_country_code
            )
            VALUES (%s, 'R2Baby Alpha', '2026-08-01', 'unknown', 'expecting',
                    %s, 'avatars/babies/' || %s || '/alpha.jpg',
                    '1 Main', 'Boston', '02101', 'US')
            """,
            (baby_id, _OWNER, str(baby_id)),
        )
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Hidden Baby', 'expecting', %s)
            """,
            (other_baby_id, _OTHER),
        )
        conn.execute(
            """
            INSERT INTO baby_profiles (id, name, lifecycle_status, created_by_firebase_uid)
            VALUES (%s, 'Visible Tag Baby', 'expecting', %s)
            """,
            (visible_baby_id, _OWNER),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (
                baby_profile_id, firebase_uid, role, relationship_label, joined_via
            )
            VALUES
                (%s, %s, 'owner', 'Mother', 'created'),
                (%s, %s, 'follower', 'Aunt', 'invite'),
                (%s, %s, 'owner', NULL, 'created'),
                (%s, %s, 'owner', 'Father', 'created')
            """,
            (
                baby_id,
                _OWNER,
                baby_id,
                _FOLLOWER,
                other_baby_id,
                _OTHER,
                visible_baby_id,
                _OWNER,
            ),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (
                baby_profile_id, firebase_uid, role, relationship_label,
                joined_via, removed_at
            )
            VALUES (%s, %s, 'follower', 'Uncle', 'invite', %s)
            """,
            (baby_id, _REMOVED, now),
        )
        photo_id = uuid.uuid4()
        conn.execute(
            """
            INSERT INTO photos (
                id, baby_profile_id, uploader_firebase_uid, status, caption,
                display_path, thumb_path, content_type
            )
            VALUES (%s, %s, %s, 'ready', 'shower day',
                    'display/alpha.jpg', 'thumbnails/alpha.jpg', 'image/jpeg')
            """,
            (photo_id, baby_id, _OWNER),
        )
        conn.execute(
            """
            INSERT INTO photo_comments (photo_id, author_firebase_uid, body)
            VALUES (%s, %s, 'so sweet')
            """,
            (photo_id, _FOLLOWER),
        )
        conn.execute(
            """
            INSERT INTO photo_comments (
                photo_id, author_firebase_uid, body, deleted_at
            )
            VALUES (%s, %s, 'deleted comment secret', now())
            """,
            (photo_id, _OWNER),
        )
        conn.execute(
            """
            INSERT INTO photo_squishes (photo_id, firebase_uid)
            VALUES (%s, %s)
            """,
            (photo_id, _FOLLOWER),
        )
        conn.execute(
            """
            INSERT INTO photo_baby_tags (photo_id, tagged_baby_profile_id)
            VALUES (%s, %s), (%s, %s)
            """,
            (photo_id, other_baby_id, photo_id, visible_baby_id),
        )
        event_id = uuid.uuid4()
        conn.execute(
            """
            INSERT INTO events (
                id, baby_profile_id, created_by_firebase_uid, title, starts_at, description
            )
            VALUES (%s, %s, %s, 'Shower', %s, 'Bring a blanket')
            """,
            (event_id, baby_id, _OWNER, now),
        )
        conn.execute(
            """
            INSERT INTO event_rsvps (event_id, firebase_uid, status)
            VALUES (%s, %s, 'going')
            """,
            (event_id, _FOLLOWER),
        )
        conn.execute(
            """
            INSERT INTO event_comments (event_id, author_firebase_uid, body)
            VALUES (%s, %s, 'I will be there')
            """,
            (event_id, _FOLLOWER),
        )
        item_id = uuid.uuid4()
        conn.execute(
            """
            INSERT INTO registry_items (
                id, baby_profile_id, created_by_firebase_uid, name, description
            )
            VALUES (%s, %s, %s, 'Stroller', 'City stroller')
            """,
            (item_id, baby_id, _OWNER),
        )
        conn.execute(
            """
            INSERT INTO registry_purchases (registry_item_id, purchased_by_firebase_uid)
            VALUES (%s, %s)
            """,
            (item_id, _FOLLOWER),
        )
        suggestion_id = uuid.uuid4()
        conn.execute(
            """
            INSERT INTO name_suggestions (
                id, baby_profile_id, suggested_by_firebase_uid, suggested_name, gender
            )
            VALUES (%s, %s, %s, 'James', 'male')
            """,
            (suggestion_id, baby_id, _FOLLOWER),
        )
        conn.execute(
            """
            INSERT INTO name_suggestion_likes (name_suggestion_id, firebase_uid)
            VALUES (%s, %s)
            """,
            (suggestion_id, _OWNER),
        )
        conn.execute(
            """
            INSERT INTO votes (
                baby_profile_id, firebase_uid, vote_type, gender_value, is_anonymous
            )
            VALUES (%s, %s, 'gender', 'female', true)
            """,
            (baby_id, _FOLLOWER),
        )
        conn.execute(
            """
            INSERT INTO votes (
                baby_profile_id, firebase_uid, vote_type, predicted_birth_date, is_anonymous
            )
            VALUES (%s, %s, 'birthdate', '2026-08-02', false)
            """,
            (baby_id, _OWNER),
        )
        conn.execute(
            """
            INSERT INTO birth_announcements (
                baby_profile_id, photo_id, first_name, last_name, gender,
                birth_date, birth_time, weight_text, length_text,
                created_by_firebase_uid
            )
            VALUES (%s, %s, 'Alpha', 'Test', 'unknown', '2026-08-01', '15:30',
                    '7 lb', '20 in', %s)
            """,
            (baby_id, photo_id, _OWNER),
        )
        announcement_id = conn.execute(
            "SELECT id FROM birth_announcements WHERE baby_profile_id = %s",
            (baby_id,),
        ).fetchone()["id"]
        conn.execute(
            """
            INSERT INTO announcement_comments (announcement_id, author_firebase_uid, body)
            VALUES (%s, %s, 'welcome')
            """,
            (announcement_id, _FOLLOWER),
        )
        conn.execute(
            """
            INSERT INTO announcement_squishes (announcement_id, firebase_uid)
            VALUES (%s, %s)
            """,
            (announcement_id, _OWNER),
        )
        conn.execute(
            """
            INSERT INTO invitations (
                baby_profile_id, inviter_firebase_uid, invitee_email, role,
                relationship_label, token_hash, status, expires_at, email_invite_token
            )
            VALUES (%s, %s, %s, 'follower', 'Grandmother', %s, 'pending', %s, %s)
            """,
            (
                baby_id,
                _OWNER,
                _PENDING_EMAIL,
                token_hash,
                now + timedelta(days=14),
                delivery_token,
            ),
        )
        conn.execute(
            """
            INSERT INTO activity_events (
                baby_profile_id, actor_firebase_uid, event_type, summary, payload
            )
            VALUES (%s, %s, 'photo_shared', 'Shared a photo', %s::jsonb)
            """,
            (
                baby_id,
                _OWNER,
                json.dumps({"actor_firebase_uid": _OWNER, "photo_id": str(photo_id)}),
            ),
        )

    with get_connection() as conn:
        raw = build_baby_export_json(
            conn,
            baby_id=baby_id,
            requester_uid=_OWNER,
            sign_read=_sign,
        )
    document = json.loads(raw)
    blob = json.dumps(document)

    assert document["export_version"] == 2
    assert set(document["covered_tables"]) == COVERED_TABLES
    assert document["baby_profile"]["name"] == "R2Baby Alpha"
    assert document["baby_profile"]["registry_shipping"]["city"] == "Boston"
    assert document["baby_profile"]["avatar"]["download_url"].startswith("https://signed.example/")

    photo = document["photos"][0]
    assert photo["caption"] == "shower day"
    assert photo["comments"][0]["body"] == "so sweet"
    assert photo["comments"][0]["person_id"].startswith("person_")
    assert photo["squishes"][0]["person_id"].startswith("person_")
    assert photo["display"]["download_url"].startswith("https://signed.example/")
    assert photo["thumbnail"]["download_url"].startswith("https://signed.example/")
    assert [tag["name"] for tag in photo["tags"]] == ["Visible Tag Baby"]
    assert "Hidden Baby" not in blob
    assert "deleted comment secret" not in blob

    event = document["events"][0]
    assert event["rsvps"][0]["status"] == "going"
    assert event["comments"][0]["body"] == "I will be there"

    item = document["registry_items"][0]
    assert item["purchase"]["person_id"].startswith("person_")
    assert item["name"] == "Stroller"

    suggestion = document["name_suggestions"][0]
    assert suggestion["suggested_name"] == "James"
    assert suggestion["loves"][0]["person_id"].startswith("person_")

    gender = document["predictions"]["gender_votes"][0]
    assert gender["is_anonymous"] is True
    assert gender["display_name"] == "Anonymous"
    assert gender["person_id"] is None
    birthdate = document["predictions"]["birthdate_votes"][0]
    assert birthdate["person_id"].startswith("person_")
    assert birthdate["predicted_birth_date"] == "2026-08-02"

    announcement = document["announcement"]
    assert announcement["first_name"] == "Alpha"
    assert announcement["comments"][0]["body"] == "welcome"
    assert announcement["squishes"]

    pending = document["invitations"][0]
    assert pending["invitee_email"] == _PENDING_EMAIL
    assert pending["relationship"] == "Grandmother"

    names = {person["display_name"]: person for person in document["members"]}
    assert names["Owner Ada"]["role"] == "owner"
    assert names["Owner Ada"]["relationship"] == "Mother"
    assert names["Follower Bea"]["role"] == "follower"
    assert names["Removed Cam"]["removed_at"] is not None

    assert document["activity_events"][0]["payload"]["person_id"].startswith("person_")
    assert "actor_firebase_uid" not in document["activity_events"][0]["payload"]

    for secret in (
        _OWNER,
        _FOLLOWER,
        _REMOVED,
        _OTHER,
        _OWNER_EMAIL,
        _FOLLOWER_EMAIL,
        _REMOVED_EMAIL,
        _OTHER_EMAIL,
        token_hash,
        delivery_token,
    ):
        assert secret not in blob

    with get_connection() as conn:
        with pytest.raises(PermissionError):
            build_baby_export_json(
                conn,
                baby_id=baby_id,
                requester_uid=_FOLLOWER,
                sign_read=_sign,
            )
