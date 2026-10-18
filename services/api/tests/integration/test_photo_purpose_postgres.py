"""Postgres: event cover purpose vs gallery list (#315)."""

from __future__ import annotations

import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.calendar import (
    create_calendar_event,
    remove_calendar_event,
    update_calendar_event,
)
from lanonna_api.domain.gallery import init_photo_upload, list_gallery, remove_photo
from lanonna_api.domain.photo_purpose import PhotoPurpose
from lanonna_api.repositories.photos import list_photos_for_baby
from lanonna_api.auth import AppUser
from types import MappingProxyType


def _owner(uid: str = "owner-uid") -> AppUser:
    return AppUser(
        uid=uid,
        email="owner@test.com",
        display_name="Owner",
        claims=MappingProxyType({"uid": uid}),
    )


pytestmark = pytest.mark.integration


@pytest.fixture
def baby_and_owner(postgres_database: str):
    from lanonna_api.repositories.babies import create_baby_with_owner_membership
    from lanonna_api.repositories.users import resolve_app_user

    resolve_app_user("owner-uid", "owner@test.com")
    row = create_baby_with_owner_membership(
        "owner-uid",
        "Test",
        "unknown",
        None,
        None,
        "expecting",
    )
    return row["id"]


def test_event_cover_not_in_gallery_list(baby_and_owner: uuid.UUID):
    baby_id = baby_and_owner
    user = _owner()
    with patch("lanonna_api.domain.gallery.mint_display_upload_for_object") as mint:
        mint.return_value = {
            "upload_url": "https://example/upload",
            "object_path": "display/x.webp",
            "content_type": "image/webp",
            "max_bytes": 2097152,
            "required_headers": {},
            "expires_in_seconds": 900,
        }
        cover = init_photo_upload(
            user,
            baby_id,
            "image/webp",
            500,
            purpose=PhotoPurpose.EVENT_COVER,
        )
        gallery = init_photo_upload(
            user,
            baby_id,
            "image/webp",
            600,
            purpose=PhotoPurpose.GALLERY,
        )
    cover_id = uuid.UUID(cover["photo_id"])
    gallery_id = uuid.UUID(gallery["photo_id"])

    from lanonna_api.db import get_connection

    with get_connection() as conn:
        conn.execute(
            "UPDATE photos SET status = 'ready', thumb_path = 'thumbnails/x.jpg' WHERE id = ANY(%s::uuid[])",
            ([cover_id, gallery_id],),
        )

    rows = list_photos_for_baby(baby_id, ready_only=False, limit=50)
    ids = {row["id"] for row in rows}
    assert gallery_id in ids
    assert cover_id not in ids

    with patch(
        "lanonna_api.domain.gallery.signed_thumb_urls",
        side_effect=lambda paths: [None for _ in paths],
    ):
        page = list_gallery("owner-uid", baby_id, limit=50, offset=0)
    listed = {uuid.UUID(item["id"]) for item in page["items"]}
    assert gallery_id in listed
    assert cover_id not in listed


def test_delete_gallery_photo_clears_event_cover(baby_and_owner: uuid.UUID):
    baby_id = baby_and_owner
    user = _owner()
    with patch("lanonna_api.domain.gallery.mint_display_upload_for_object") as mint:
        mint.return_value = {
            "upload_url": "https://example/upload",
            "object_path": "display/x.webp",
            "content_type": "image/webp",
            "max_bytes": 2097152,
            "required_headers": {},
            "expires_in_seconds": 900,
        }
        gallery = init_photo_upload(user, baby_id, "image/webp", 600)
    photo_id = uuid.UUID(gallery["photo_id"])

    from lanonna_api.db import get_connection

    with get_connection() as conn:
        conn.execute(
            "UPDATE photos SET status = 'ready', thumb_path = 'thumbnails/x.jpg' WHERE id = %s",
            (photo_id,),
        )

    event = create_calendar_event(
        "owner-uid",
        baby_id,
        title="Party",
        starts_at=__import__("datetime").datetime(2030, 1, 1, tzinfo=__import__("datetime").timezone.utc),
        ends_at=None,
        description=None,
        location=None,
        video_call_url=None,
        cover_photo_id=photo_id,
    )
    event_id = uuid.UUID(event["id"])

    with patch("lanonna_api.storage.delete_photo_objects_best_effort"):
        remove_photo("owner-uid", baby_id, photo_id)

    with get_connection() as conn:
        row = conn.execute(
            "SELECT cover_photo_id FROM events WHERE id = %s",
            (event_id,),
        ).fetchone()
    assert row["cover_photo_id"] is None


def test_replace_event_cover_purges_orphan_event_cover(baby_and_owner: uuid.UUID):
    baby_id = baby_and_owner
    user = _owner()
    with patch("lanonna_api.domain.gallery.mint_display_upload_for_object") as mint:
        mint.return_value = {
            "upload_url": "https://example/upload",
            "object_path": "display/x.webp",
            "content_type": "image/webp",
            "max_bytes": 2097152,
            "required_headers": {},
            "expires_in_seconds": 900,
        }
        first = init_photo_upload(
            user, baby_id, "image/webp", 500, purpose=PhotoPurpose.EVENT_COVER
        )
        second = init_photo_upload(
            user, baby_id, "image/webp", 500, purpose=PhotoPurpose.EVENT_COVER
        )
    first_id = uuid.UUID(first["photo_id"])
    second_id = uuid.UUID(second["photo_id"])

    from lanonna_api.db import get_connection

    with get_connection() as conn:
        conn.execute(
            "UPDATE photos SET status = 'ready', thumb_path = 'thumbnails/x.jpg' WHERE id = ANY(%s::uuid[])",
            ([first_id, second_id],),
        )

    event = create_calendar_event(
        "owner-uid",
        baby_id,
        title="Party",
        starts_at=__import__("datetime").datetime(2030, 1, 1, tzinfo=__import__("datetime").timezone.utc),
        ends_at=None,
        description=None,
        location=None,
        video_call_url=None,
        cover_photo_id=first_id,
    )
    event_id = uuid.UUID(event["id"])

    with patch("lanonna_api.storage.delete_photo_objects_best_effort"):
        update_calendar_event(
            "owner-uid",
            baby_id,
            event_id,
            {"cover_photo_id": second_id},
        )

    with get_connection() as conn:
        exists = conn.execute(
            "SELECT 1 FROM photos WHERE id = %s",
            (first_id,),
        ).fetchone()
    assert exists is None


def test_delete_event_purges_event_cover(baby_and_owner: uuid.UUID):
    baby_id = baby_and_owner
    user = _owner()
    with patch("lanonna_api.domain.gallery.mint_display_upload_for_object") as mint:
        mint.return_value = {
            "upload_url": "https://example/upload",
            "object_path": "display/x.webp",
            "content_type": "image/webp",
            "max_bytes": 2097152,
            "required_headers": {},
            "expires_in_seconds": 900,
        }
        cover = init_photo_upload(
            user, baby_id, "image/webp", 500, purpose=PhotoPurpose.EVENT_COVER
        )
    cover_id = uuid.UUID(cover["photo_id"])

    from lanonna_api.db import get_connection

    with get_connection() as conn:
        conn.execute(
            "UPDATE photos SET status = 'ready', thumb_path = 'thumbnails/x.jpg' WHERE id = %s",
            (cover_id,),
        )

    event = create_calendar_event(
        "owner-uid",
        baby_id,
        title="Party",
        starts_at=__import__("datetime").datetime(2030, 1, 1, tzinfo=__import__("datetime").timezone.utc),
        ends_at=None,
        description=None,
        location=None,
        video_call_url=None,
        cover_photo_id=cover_id,
    )
    event_id = uuid.UUID(event["id"])

    with patch("lanonna_api.storage.delete_photo_objects_best_effort"):
        remove_calendar_event("owner-uid", baby_id, event_id)

    with get_connection() as conn:
        exists = conn.execute(
            "SELECT 1 FROM photos WHERE id = %s",
            (cover_id,),
        ).fetchone()
    assert exists is None


def _ready_photo(baby_id: uuid.UUID, purpose: PhotoPurpose) -> uuid.UUID:
    with patch("lanonna_api.domain.gallery.mint_display_upload_for_object") as mint:
        mint.return_value = {
            "upload_url": "https://example/upload",
            "object_path": "display/x.webp",
            "content_type": "image/webp",
            "max_bytes": 2097152,
            "required_headers": {},
            "expires_in_seconds": 900,
        }
        photo = init_photo_upload(
            _owner(), baby_id, "image/webp", 500, purpose=purpose
        )
    photo_id = uuid.UUID(photo["photo_id"])
    from lanonna_api.db import get_connection

    with get_connection() as conn:
        conn.execute(
            "UPDATE photos SET status = 'ready', byte_length = 500, "
            "thumb_path = 'thumbnails/x.jpg' WHERE id = %s",
            (photo_id,),
        )
    return photo_id


def _event_with_cover(baby_id: uuid.UUID, cover_id: uuid.UUID) -> uuid.UUID:
    from datetime import datetime, timezone

    event = create_calendar_event(
        "owner-uid",
        baby_id,
        title="Party",
        starts_at=datetime(2030, 1, 1, tzinfo=timezone.utc),
        ends_at=None,
        description=None,
        location=None,
        video_call_url=None,
        cover_photo_id=cover_id,
    )
    return uuid.UUID(event["id"])


def test_cover_id_is_not_a_gallery_item(baby_and_owner: uuid.UUID):
    """Deep link /gallery/photo/{cover id}: detail, squish, comment, caption,
    tags and delete all answer "not found"; the event still shows the cover."""
    from lanonna_api.domain import gallery
    from lanonna_api.domain.calendar import get_event_detail

    baby_id = baby_and_owner
    cover_id = _ready_photo(baby_id, PhotoPurpose.EVENT_COVER)
    event_id = _event_with_cover(baby_id, cover_id)

    with pytest.raises(LookupError):
        gallery.get_photo_detail("owner-uid", baby_id, cover_id)
    with pytest.raises(LookupError):
        gallery.squish_photo("owner-uid", baby_id, cover_id)
    with pytest.raises(LookupError):
        gallery.add_comment("owner-uid", baby_id, cover_id, "hi")
    with pytest.raises(LookupError):
        gallery.patch_caption("owner-uid", baby_id, cover_id, "x")
    with pytest.raises(LookupError):
        gallery.set_photo_baby_tags("owner-uid", baby_id, cover_id, [])
    with pytest.raises(LookupError):
        gallery.remove_photo("owner-uid", baby_id, cover_id)

    with patch("lanonna_api.domain.calendar.signed_display_url", return_value="u"):
        detail = get_event_detail("owner-uid", baby_id, event_id)
    assert detail["cover_photo_id"] == str(cover_id)
    assert detail["cover_photo_display_url"] == "u"


def test_cover_counts_for_storage_but_not_home_checklist(baby_and_owner: uuid.UUID):
    from lanonna_api.repositories.home_counts import home_summary_counts
    from lanonna_api.repositories.user_engagement import (
        storage_usage_for_owner_babies,
    )

    baby_id = baby_and_owner
    _ready_photo(baby_id, PhotoPurpose.EVENT_COVER)
    assert home_summary_counts(baby_id)["has_photo"] is False
    assert storage_usage_for_owner_babies("owner-uid")["used_bytes"] == 500


def test_replacing_gallery_cover_keeps_gallery_photo(baby_and_owner: uuid.UUID):
    """The orphan purge only ever deletes event_cover rows."""
    baby_id = baby_and_owner
    gallery_id = _ready_photo(baby_id, PhotoPurpose.GALLERY)
    other_id = _ready_photo(baby_id, PhotoPurpose.EVENT_COVER)
    event_id = _event_with_cover(baby_id, gallery_id)

    with patch("lanonna_api.storage.delete_photo_objects_best_effort") as objects:
        update_calendar_event(
            "owner-uid", baby_id, event_id, {"cover_photo_id": other_id}
        )
        remove_calendar_event("owner-uid", baby_id, event_id)

    from lanonna_api.db import get_connection

    with get_connection() as conn:
        remaining = {
            r["id"]
            for r in conn.execute(
                "SELECT id FROM photos WHERE id = ANY(%s::uuid[])",
                ([gallery_id, other_id],),
            ).fetchall()
        }
    assert remaining == {gallery_id}
    objects.assert_called_once_with(
        display_path=f"display/{other_id}.webp", thumb_path="thumbnails/x.jpg"
    )


def test_shared_cover_survives_until_last_event_drops_it(baby_and_owner: uuid.UUID):
    baby_id = baby_and_owner
    cover_id = _ready_photo(baby_id, PhotoPurpose.EVENT_COVER)
    first = _event_with_cover(baby_id, cover_id)
    second = _event_with_cover(baby_id, cover_id)

    with patch("lanonna_api.storage.delete_photo_objects_best_effort") as objects:
        remove_calendar_event("owner-uid", baby_id, first)
        objects.assert_not_called()
        remove_calendar_event("owner-uid", baby_id, second)
        objects.assert_called_once()
