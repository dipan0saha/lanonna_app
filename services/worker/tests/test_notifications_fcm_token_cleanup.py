from firebase_admin import messaging

from lanonna_worker.notifications import _should_delete_fcm_token


def test_should_delete_fcm_token_for_unregistered():
    assert _should_delete_fcm_token(messaging.UnregisteredError("gone"))


def test_should_not_delete_fcm_token_for_unknown_error():
    assert not _should_delete_fcm_token(RuntimeError("temporary"))
