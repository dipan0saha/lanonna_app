import uuid
from datetime import datetime, timezone

from lanonna_api.domain.activity_copy import (
    actor_name_from_row,
    photo_id_from_payload,
    serialize_activity_item,
)


def test_photo_id_from_payload_valid():
    pid = uuid.uuid4()
    assert photo_id_from_payload({"photo_id": str(pid)}) == pid


def test_photo_id_from_payload_invalid():
    assert photo_id_from_payload({"photo_id": "not-a-uuid"}) is None
    assert photo_id_from_payload(None) is None


def test_actor_name_from_row():
    assert actor_name_from_row({"actor_display_name": "  Pat  "}) == "Pat"
    assert actor_name_from_row({"actor_display_name": "   "}) is None


def test_serialize_activity_item():
    photo_id = uuid.uuid4()
    created = datetime(2026, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    row = {
        "id": uuid.uuid4(),
        "event_type": "photo_squish",
        "summary": "Sam squished",
        "created_at": created,
        "actor_display_name": "Sam",
        "payload": {"photo_id": str(photo_id)},
    }
    item = serialize_activity_item(row)
    assert item["event_type"] == "photo_squish"
    assert item["actor_display_name"] == "Sam"
    assert item["photo_id"] == str(photo_id)
    assert item["created_at"] == created.isoformat()
