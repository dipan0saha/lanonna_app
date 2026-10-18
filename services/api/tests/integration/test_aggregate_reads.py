"""Home summary, photo detail and names on real Postgres: same payload, fewer round trips.

Before this change (measured on the same seed with the previous code):

=================  ==========  ===========
read               statements  connections
=================  ==========  ===========
home (owner)       17          17 (a new connection per query)
home (follower)    11          11
photo detail        6           6
fun names           5           5
=================  ==========  ===========

Each aggregate now runs bounded queries on one pooled connection.
"""

from __future__ import annotations

import uuid
from contextlib import contextmanager

import psycopg
import pytest
from psycopg_pool import ConnectionPool

from lanonna_api import db, storage
from lanonna_api.domain.fun import list_names
from lanonna_api.domain.gallery import get_photo_detail
from lanonna_api.domain.home import build_home_summary

from family_seed import FOLLOWER, OWNER, seed_family


class _FakeBackend:
    def __init__(self) -> None:
        self.signed: list[tuple[str, str]] = []

    def sign(self, bucket, object_name, **_kwargs):
        self.signed.append((bucket, object_name))
        return f"https://signed/{bucket}/{object_name}"


@pytest.fixture
def signer(monkeypatch):
    backend = _FakeBackend()
    signer = storage.GcsUrlSigner(lambda: backend)
    monkeypatch.setattr(storage, "_url_signer", signer)
    return backend


@pytest.fixture
def family():
    return seed_family()


@contextmanager
def _counting(monkeypatch):
    counts = {"statements": 0, "checkouts": 0}
    execute = psycopg.Cursor.execute
    getconn = ConnectionPool.getconn

    def counted_execute(self, query, *args, **kwargs):
        if query != "":  # the pool's liveness check
            counts["statements"] += 1
        return execute(self, query, *args, **kwargs)

    def counted_getconn(self, *args, **kwargs):
        counts["checkouts"] += 1
        return getconn(self, *args, **kwargs)

    db.open_pool().wait()
    with monkeypatch.context() as m:
        m.setattr(psycopg.Cursor, "execute", counted_execute)
        m.setattr(ConnectionPool, "getconn", counted_getconn)
        yield counts


def _s(value) -> str:
    return str(value)


def _ids(items) -> list[str]:
    return [_s(item["id"]) for item in items]


def test_owner_home_summary_payload_and_round_trips(family, signer, monkeypatch):
    baby = family["baby_id"]
    photos = family["photos"]
    events = family["events"]
    with _counting(monkeypatch) as counts:
        data = build_home_summary(OWNER, baby)

    assert counts["checkouts"] == 1
    assert counts["statements"] <= 9  # was 17 statements on 17 connections

    assert data["lifecycle_status"] == "expecting"
    assert data["days_to_due"] == 40
    # Removed member's votes, likes and squishes are excluded.
    assert data["family_insight"] == {
        "name_suggestion_count": 4,
        "vote_count": 3,
        "gender_totals": {"male": 2, "female": 1},
        "top_name": {"suggested_name": "Milo", "like_count": 2},
        "top_birthdate_guess": "2026-11-20",
        "show_rich_insight": True,
    }
    assert _s(data["next_up_event"]["id"]) == _s(events[2])
    assert _ids(data["teasers"]["upcoming_events"]) == [
        _s(e) for e in events[2:5]
    ]
    assert _ids(data["teasers"]["recent_photos"]) == [
        _s(photos[i]) for i in (6, 5, 4, 3)
    ]
    assert data["teasers"]["recent_photos"][0]["thumb_url"] == (
        f"https://signed/lanonna-dev-thumbnails/thumbs/{photos[6]}.jpg"
    )
    started = data["getting_started"]
    assert (started["completed_count"], started["total"]) == (5, 5)
    assert [i["invitee_email"] for i in data["invite_status"]] == [
        f"guest{i}@example.com" for i in range(5)
    ]
    assert {i["status"] for i in data["invite_status"]} == {"pending"}
    assert [f["firebase_uid"] for f in data["new_followers"]] == [FOLLOWER]
    assert len(data["recent_activity"]) == 10
    assert {a["title"] for a in data["system_announcements"]} == {"Owners only", "Welcome"}
    assert data["birth_welcome"] is None


def test_follower_home_summary_hides_owner_sections(family, signer, monkeypatch):
    with _counting(monkeypatch) as counts:
        data = build_home_summary(FOLLOWER, family["baby_id"])
    assert counts["checkouts"] == 1
    assert counts["statements"] <= 7  # was 11 on 11 connections
    assert data["getting_started"] is None
    assert data["invite_status"] is None
    assert data["new_followers"] is None
    assert {a["title"] for a in data["system_announcements"]} == {"Welcome"}


def test_photo_detail_payload_and_round_trips(family, signer, monkeypatch):
    photo = family["detail_photo"]
    signer.signed.clear()
    with _counting(monkeypatch) as counts:
        data = get_photo_detail(FOLLOWER, family["baby_id"], photo)

    assert counts["checkouts"] == 1
    assert counts["statements"] <= 4  # was 6 on 6 connections
    assert _s(data["id"]) == _s(photo)
    assert data["squish_count"] == 2  # removed member's squish excluded
    assert data["viewer_has_squished"] is True
    assert data["uploader_display_name"] == "Aunt May"
    assert [c["body"] for c in data["comments"]] == ["Lovely", "So cute"]
    assert [(_s(t["id"]), t["name"]) for t in data["tagged_babies"]] == [
        (_s(family["baby_id"]), "Parker")
    ]
    assert data["display_url"] == f"https://signed/lanonna-dev-display/display/{photo}.webp"
    assert data["thumb_url"] == f"https://signed/lanonna-dev-thumbnails/thumbs/{photo}.jpg"
    # Display and thumb were signed together; a repeat view is served from cache.
    assert len(signer.signed) == 2
    get_photo_detail(FOLLOWER, family["baby_id"], photo)
    assert len(signer.signed) == 2


def test_names_payload_and_round_trips(family, signer, monkeypatch):
    with _counting(monkeypatch) as counts:
        data = list_names(FOLLOWER, family["baby_id"])
    assert counts["checkouts"] == 1
    assert counts["statements"] <= 3  # was 5 on 5 connections
    assert [(s["suggested_name"], s["like_count"], s["viewer_has_liked"]) for s in data["suggestions"]] == [
        ("Milo", 2, True),
        ("Ava", 1, False),
        ("Theo", 1, False),
        ("Robin", 0, False),
    ]
    milo = _s(data["suggestions"][0]["id"])
    liked = data["viewer_liked_by_gender"]
    assert (_s(liked["male"]), liked["female"]) == (milo, None)
    assert data["names_closed"] is False


def test_unknown_photo_still_404s_inside_the_scope(family, signer):
    with pytest.raises(LookupError, match="Photo not found"):
        get_photo_detail(FOLLOWER, family["baby_id"], uuid.uuid4())
