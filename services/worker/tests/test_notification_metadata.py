from lanonna_worker.notification_metadata import (
    actor_uid_from_payload,
    notification_type_from_payload,
)


def test_notification_type_defaults_and_rejects_unknown():
    assert notification_type_from_payload({}) == "generic"
    assert notification_type_from_payload({"notification_type": "photo"}) == "photo"
    assert notification_type_from_payload({"notification_type": "bogus"}) == "generic"


def test_actor_uid_from_payload():
    assert actor_uid_from_payload({}) is None
    assert actor_uid_from_payload({"actor_firebase_uid": "u1"}) == "u1"
