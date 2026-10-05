import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.invitations import (
    BatchInviteRow,
    accept_invitation,
    batch_invite,
    revoke_invitation_for_owner,
)


def test_batch_invite_skips_existing_member():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.invitations.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch("lanonna_api.domain.invitations.email_is_member", return_value=True),
    ):
        results = batch_invite(
            "owner-1",
            baby_id,
            [BatchInviteRow("a@test.com", "follower", None)],
        )
    assert results[0]["status"] == "skipped_member"


def test_batch_invite_email_queue_failed_returns_row_not_raises():
    baby_id = uuid.uuid4()
    inv_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.invitations.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch("lanonna_api.domain.invitations.email_is_member", return_value=False),
        patch(
            "lanonna_api.domain.invitations.email_has_pending_invite",
            return_value=False,
        ),
        patch(
            "lanonna_api.domain.invitations.create_invitation",
            return_value={"id": inv_id, "invite_token": "tok"},
        ),
        patch(
            "lanonna_api.domain.invitations.publish_send_invite_email",
            side_effect=RuntimeError("pubsub down"),
        ),
    ):
        results = batch_invite(
            "owner-1",
            baby_id,
            [BatchInviteRow("a@test.com", "follower", None)],
        )
    assert len(results) == 1
    assert results[0]["status"] == "email_queue_failed"
    assert results[0]["invitation_id"] == inv_id
    assert results[0]["message"]

def test_revoke_invitation_not_found_raises_lookup():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.invitations.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch("lanonna_api.domain.invitations.revoke_invitation", return_value=False),
    ):
        with pytest.raises(LookupError):
            revoke_invitation_for_owner("owner-1", baby_id, uuid.uuid4())


def test_accept_invitation_enqueues_notify_on_success():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.invitations.accept_invitation_by_token",
            return_value={
                "already_member": False,
                "baby_profile_id": baby_id,
                "inviter_firebase_uid": "owner-1",
                "baby_name": "Luna",
            },
        ),
        patch(
            "lanonna_api.domain.invitations.safe_enqueue_notify_user",
        ) as notify,
        patch(
            "lanonna_api.domain.invitations.actor_display_name",
            return_value="Alex",
        ),
    ):
        result = accept_invitation("token", "uid-1", "a@test.com")
    assert result["baby_profile_id"] == baby_id
    notify.assert_called_once()
