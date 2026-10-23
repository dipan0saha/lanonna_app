"""Cross-account storage references, end to end against Postgres (#415).

An attacker who owns one baby and follows the victim's baby tries to point
every field that names a stored object or a link at something that isn't
theirs. Avatars name objects directly; covers and announcement photos name a
photo id the API looks up under the baby; links must be https.
"""

from __future__ import annotations

import uuid
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import patch

import psycopg
import pytest
from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.config import settings
from lanonna_api.db import get_connection
from lanonna_api.main import app
from lanonna_api.repositories.users import resolve_app_user

client = TestClient(app)
VICTIM = "victim-uid"
ATTACKER = "attacker-uid"
_MIGRATION_049 = (
    Path(__file__).resolve().parents[4]
    / "infra/db/migrations/049_owned_avatar_references.sql"
)


@contextmanager
def as_user(uid: str):
    app.dependency_overrides[current_user] = lambda: {"uid": uid, "email": f"{uid}@example.test"}
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


@pytest.fixture(autouse=True)
def _fake_signing():
    with patch(
        "lanonna_api.domain.media_urls.mint_signed_read_urls",
        side_effect=lambda refs: [f"https://signed.example/{path}" for _bucket, path in refs],
    ):
        yield


def _baby(conn, owner: str) -> uuid.UUID:
    baby_id = uuid.uuid4()
    conn.execute(
        """
        INSERT INTO baby_profiles (id, name, lifecycle_status, actual_birth_date,
                                   created_by_firebase_uid)
        VALUES (%s, 'Baby', 'born', current_date - 3, %s)
        """,
        (baby_id, owner),
    )
    conn.execute(
        """
        INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
        VALUES (%s, %s, 'owner', 'created')
        """,
        (baby_id, owner),
    )
    return baby_id


def _photo(conn, baby_id: uuid.UUID, uploader: str) -> uuid.UUID:
    pid = uuid.uuid4()
    conn.execute(
        """
        INSERT INTO photos (id, baby_profile_id, uploader_firebase_uid, status,
                            display_path, thumb_path, caption)
        VALUES (%s, %s, %s, 'ready', %s, %s, 'x')
        """,
        (pid, baby_id, uploader, f"display/{pid}.webp", f"thumb/{pid}.webp"),
    )
    return pid


@pytest.fixture()
def world():
    resolve_app_user(VICTIM, "victim@example.test")
    resolve_app_user(ATTACKER, "attacker@example.test")
    with get_connection() as conn:
        victim_baby = _baby(conn, VICTIM)
        attacker_baby = _baby(conn, ATTACKER)
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'follower', 'invite')
            """,
            (victim_baby, ATTACKER),
        )
        victim_avatar = f"avatars/users/{VICTIM}/me.webp"
        victim_baby_avatar = f"avatars/babies/{victim_baby}/baby.webp"
        conn.execute(
            "UPDATE app_users SET avatar_url = %s WHERE firebase_uid = %s",
            (victim_avatar, VICTIM),
        )
        conn.execute(
            "UPDATE baby_profiles SET avatar_url = %s WHERE id = %s",
            (victim_baby_avatar, victim_baby),
        )
        victim_photo = _photo(conn, victim_baby, VICTIM)
    return {
        "victim_baby": victim_baby,
        "attacker_baby": attacker_baby,
        "victim_avatar": victim_avatar,
        "victim_baby_avatar": victim_baby_avatar,
        "victim_photo": victim_photo,
    }


def _scalar(sql: str, params: tuple):
    with get_connection() as conn:
        row = conn.execute(sql, params).fetchone()
        return next(iter(row.values()))


def _foreign_references(world) -> list[str]:
    bucket = settings.display_bucket
    return [
        world["victim_avatar"],
        world["victim_baby_avatar"],
        f"https://storage.googleapis.com/{bucket}/{world['victim_avatar']}",
        f"https://storage.googleapis.com/{bucket}/{world['victim_avatar']}?X-Goog-Signature=1",
        f"avatars/users/{ATTACKER}/../{VICTIM}/me.webp",
        f"display/{world['victim_photo']}.webp",
        "smoke/probe.webp",
        "https://tracker.example.com/pixel.png",
        "http://tracker.example.com/pixel.png",
    ]


def _assert_rejected(response) -> None:
    assert response.status_code == 400, response.text
    assert response.json()["detail"]["error"] == "invalid_storage_reference"


def test_user_avatar_takes_only_the_callers_own_object(world):
    with as_user(ATTACKER):
        for value in _foreign_references(world):
            _assert_rejected(client.patch("/v1/profile", json={"avatar_url": value}))
        own = f"avatars/users/{ATTACKER}/me.webp"
        ok = client.patch("/v1/profile", json={"avatar_url": own})
    assert ok.status_code == 200, ok.text
    assert ok.json()["avatar_url"] == f"https://signed.example/{own}"
    assert _scalar("SELECT avatar_url FROM app_users WHERE firebase_uid = %s", (ATTACKER,)) == own


def test_baby_avatar_takes_only_that_babys_object(world):
    baby = world["attacker_baby"]
    with as_user(ATTACKER):
        for value in _foreign_references(world) + [f"avatars/users/{ATTACKER}/me.webp"]:
            _assert_rejected(client.patch(f"/v1/babies/{baby}", json={"avatar_url": value}))
    assert _scalar("SELECT avatar_url FROM baby_profiles WHERE id = %s", (baby,)) is None


def test_follower_cannot_set_the_followed_babys_avatar(world):
    baby = world["victim_baby"]
    with as_user(ATTACKER):
        response = client.patch(
            f"/v1/babies/{baby}",
            json={"avatar_url": f"avatars/babies/{baby}/swap.webp"},
        )
    assert response.status_code == 403, response.text
    assert (
        _scalar("SELECT avatar_url FROM baby_profiles WHERE id = %s", (baby,))
        == world["victim_baby_avatar"]
    )


def test_follower_cannot_mint_an_upload_into_the_followed_babys_prefix(world):
    with as_user(ATTACKER):
        response = client.post(
            "/v1/uploads/display/signed-url",
            json={
                "scope": "baby",
                "baby_profile_id": str(world["victim_baby"]),
                "content_type": "image/webp",
                "byte_length": 1000,
            },
        )
    assert response.status_code == 404, response.text


def test_event_cover_must_be_a_photo_of_that_baby(world):
    baby = world["attacker_baby"]
    with as_user(ATTACKER):
        response = client.post(
            f"/v1/babies/{baby}/events",
            json={
                "title": "Party",
                "starts_at": "2030-01-01T18:00:00Z",
                "cover_photo_id": str(world["victim_photo"]),
            },
        )
    assert response.status_code == 400, response.text
    assert _scalar("SELECT count(*) FROM events WHERE baby_profile_id = %s", (baby,)) == 0


def test_announcement_photo_must_be_a_photo_of_that_baby(world):
    baby = world["attacker_baby"]
    with as_user(ATTACKER):
        response = client.put(
            f"/v1/babies/{baby}/announcement",
            json={"first_name": "Leo", "photo_id": str(world["victim_photo"])},
        )
    assert response.status_code == 400, response.text


def test_gallery_does_not_serve_another_babys_photo(world):
    with as_user(ATTACKER):
        response = client.get(
            f"/v1/babies/{world['attacker_baby']}/photos/{world['victim_photo']}"
        )
    assert response.status_code == 404, response.text


@pytest.mark.parametrize("link", ["http://shop.example.com/x", "http://localhost/x"])
def test_links_must_be_https(world, link):
    baby = world["attacker_baby"]
    with as_user(ATTACKER):
        item = client.post(
            f"/v1/babies/{baby}/registry/items",
            json={"name": "Stroller", "product_url": link},
        )
        event = client.post(
            f"/v1/babies/{baby}/events",
            json={"title": "Call", "starts_at": "2030-01-01T18:00:00Z", "video_call_url": link},
        )
    for response in (item, event):
        assert response.status_code == 400, response.text
        assert response.json()["detail"]["error"] == "invalid_url"


def _lift_avatar_constraints() -> None:
    """Simulate rows written before #415 (049 restores the constraints)."""
    with get_connection() as conn:
        conn.execute("ALTER TABLE app_users DROP CONSTRAINT app_users_avatar_url_owned")
        conn.execute("ALTER TABLE baby_profiles DROP CONSTRAINT baby_profiles_avatar_url_owned")


def _apply_049() -> None:
    with get_connection() as conn, psycopg.ClientCursor(conn) as cur:
        cur.execute(_MIGRATION_049.read_text())


def test_reads_never_sign_an_unowned_legacy_avatar(world):
    _lift_avatar_constraints()
    try:
        with get_connection() as conn:
            conn.execute(
                "UPDATE app_users SET avatar_url = %s WHERE firebase_uid = %s",
                (world["victim_avatar"], ATTACKER),
            )
            conn.execute(
                "UPDATE baby_profiles SET avatar_url = %s WHERE id = %s",
                ("https://tracker.example.com/p.png", world["attacker_baby"]),
            )
        with as_user(ATTACKER):
            profile = client.get("/v1/me/account")
            babies = client.get("/v1/babies")
    finally:
        _apply_049()
    assert profile.status_code == 200, profile.text
    assert profile.json()["profile"]["avatar_url"] is None
    assert {b["id"]: b for b in profile.json()["babies"]}[str(world["attacker_baby"])]["avatar_url"] is None
    assert babies.status_code == 200, babies.text
    by_id = {b["id"]: b for b in babies.json()["items"]}
    assert by_id[str(world["attacker_baby"])]["avatar_url"] is None
    assert (
        by_id[str(world["victim_baby"])]["avatar_url"]
        == f"https://signed.example/{world['victim_baby_avatar']}"
    )


def test_migration_049_cleans_legacy_rows_and_enforces_ownership(world):
    bucket = settings.display_bucket
    own_url = f"https://storage.googleapis.com/{bucket}/avatars/users/{VICTIM}/me.webp?sig=1"
    _lift_avatar_constraints()
    with get_connection() as conn:
        conn.execute(
            "UPDATE app_users SET avatar_url = %s WHERE firebase_uid = %s", (own_url, VICTIM)
        )
        conn.execute(
            "UPDATE app_users SET avatar_url = %s WHERE firebase_uid = %s",
            (f"avatars/users/{VICTIM}/me.webp", ATTACKER),
        )
        conn.execute(
            "UPDATE baby_profiles SET avatar_url = %s WHERE id = %s",
            (world["victim_baby_avatar"], world["attacker_baby"]),
        )
    _apply_049()
    assert (
        _scalar("SELECT avatar_url FROM app_users WHERE firebase_uid = %s", (VICTIM,))
        == f"avatars/users/{VICTIM}/me.webp"
    )
    assert _scalar("SELECT avatar_url FROM app_users WHERE firebase_uid = %s", (ATTACKER,)) is None
    assert (
        _scalar("SELECT avatar_url FROM baby_profiles WHERE id = %s", (world["attacker_baby"],))
        is None
    )
    assert (
        _scalar("SELECT avatar_url FROM baby_profiles WHERE id = %s", (world["victim_baby"],))
        == world["victim_baby_avatar"]
    )
    for bad in (
        f"avatars/users/{VICTIM}/me.webp",
        f"avatars/users/{ATTACKER}/nested/me.webp",
        f"avatars/users/{ATTACKER}/..",
        "https://tracker.example.com/p.png",
    ):
        with pytest.raises(psycopg.errors.CheckViolation):
            with get_connection() as conn:
                conn.execute(
                    "UPDATE app_users SET avatar_url = %s WHERE firebase_uid = %s",
                    (bad, ATTACKER),
                )
