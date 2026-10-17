import uuid
from datetime import datetime, timezone

from lanonna_api.domain.activity_feed import (
    photo_id_from_payload,
    serialize_activity_item,
)


def _row(**overrides):
    row = {
        "id": uuid.uuid4(),
        "event_type": "photo_squish",
        "params": {"caption": "Nursery"},
        "summary": "Sam squished \"Nursery\"",
        "created_at": datetime(2026, 1, 2, 3, 4, 5, tzinfo=timezone.utc),
        "actor_display_name": "Sam",
        "target_display_name": None,
        "payload": None,
    }
    row.update(overrides)
    return row


def test_photo_id_from_payload_valid():
    pid = uuid.uuid4()
    assert photo_id_from_payload({"photo_id": str(pid)}) == pid


def test_photo_id_from_payload_invalid():
    assert photo_id_from_payload({"photo_id": "not-a-uuid"}) is None
    assert photo_id_from_payload(None) is None


def test_serialize_activity_item_is_structured():
    photo_id = uuid.uuid4()
    row = _row(payload={"photo_id": str(photo_id)})
    item = serialize_activity_item(row)
    assert item["event_type"] == "photo_squish"
    assert item["params"] == {"caption": "Nursery"}
    assert item["actor_display_name"] == "Sam"
    assert item["target_display_name"] is None
    assert item["photo_id"] == str(photo_id)
    assert item["created_at"] == row["created_at"].isoformat()


def test_serialize_activity_item_blank_names_are_null_not_english():
    item = serialize_activity_item(
        _row(event_type="member_removed", params={}, actor_display_name="  ",
             target_display_name="")
    )
    assert item["actor_display_name"] is None
    assert item["target_display_name"] is None


def test_follower_registry_claim_hides_the_buyer():
    item = serialize_activity_item(
        _row(event_type="registry_claimed", params={"item_name": "Swaddles"})
    )
    assert item["actor_display_name"] is None
    assert item["params"] == {"item_name": "Swaddles"}
