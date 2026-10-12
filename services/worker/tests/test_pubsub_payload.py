import base64
import json

from lanonna_worker.pubsub_payload import decode_pubsub_data, validate_notify_fan_out_payload


def test_decode_empty_data():
    assert decode_pubsub_data("") == {}


def test_decode_valid_json():
    raw = base64.b64encode(json.dumps({"type": "x"}).encode()).decode()
    assert decode_pubsub_data(raw) == {"type": "x"}


def test_decode_invalid_base64_returns_empty():
    assert decode_pubsub_data("@@@") == {}


def test_validate_notify_fan_out_missing_title():
    assert not validate_notify_fan_out_payload(
        {"baby_profile_id": "00000000-0000-4000-8000-000000000001"}
    )
