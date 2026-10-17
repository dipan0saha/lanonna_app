import base64
import json

from lanonna_worker.pubsub_payload import (
    decode_pubsub_data,
    validate_notify_fan_out_payload,
    validate_notify_user_payload,
)

_BABY = "00000000-0000-4000-8000-000000000001"


def test_decode_empty_data():
    assert decode_pubsub_data("") == {}


def test_decode_valid_json():
    raw = base64.b64encode(json.dumps({"type": "x"}).encode()).decode()
    assert decode_pubsub_data(raw) == {"type": "x"}


def test_decode_invalid_base64_returns_empty():
    assert decode_pubsub_data("@@@") == {}


def test_notify_payload_without_kind_is_rejected():
    assert not validate_notify_fan_out_payload({"baby_profile_id": _BABY})
    # Pre-038 server-written copy is not delivered.
    assert not validate_notify_fan_out_payload(
        {"baby_profile_id": _BABY, "title": "New photo", "body": "Sarah shared a photo"}
    )


def test_notify_payload_kind_must_be_an_inbox_kind():
    assert validate_notify_fan_out_payload({"baby_profile_id": _BABY, "kind": "photo_shared"})
    assert not validate_notify_fan_out_payload({"baby_profile_id": _BABY, "kind": "weekly_digest"})
    assert not validate_notify_user_payload({"firebase_uid": "u1", "kind": "made_up"})
    assert validate_notify_user_payload(
        {"firebase_uid": "u1", "kind": "event_rsvp", "params": {"rsvp_status": "going"}}
    )


def test_notify_payload_params_must_be_an_object():
    assert not validate_notify_user_payload(
        {"firebase_uid": "u1", "kind": "event_rsvp", "params": ["going"]}
    )
