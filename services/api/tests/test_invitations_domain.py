import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.invitations import (
    BatchInviteRow,
    accept_invitation,
    batch_invite,
    revoke_invitation_for_owner,
)


def _batch(rows, *, targets, prepared=(), created=None, publish=None):
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.invitations.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.invitations.load_invite_targets",
            return_value=targets,
        ) as load,
        patch(
            "lanonna_api.domain.invitations.write_batch_invitations",
            return_value=(set(prepared), created or {}),
        ) as write,
        patch(
            "lanonna_api.domain.invitations.publish_send_invite_email",
            **({"side_effect": publish} if publish else {}),
        ) as pub,
    ):
        results = batch_invite(
            "owner-1",
            baby_id,
            [BatchInviteRow(email, "follower", None) for email in rows],
        )
    return results, load, write, pub


def test_batch_invite_reads_and_writes_once_for_all_rows():
    sent, unsent, new_id = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    results, load, write, pub = _batch(
        ["Member@Test.com", "sent@test.com", "unsent@test.com", "new@test.com", "NEW@test.com"],
        targets={
            "member@test.com": {"is_member": True, "pending_id": None, "pending_email_sent": False},
            "sent@test.com": {"is_member": False, "pending_id": sent, "pending_email_sent": True},
            "unsent@test.com": {"is_member": False, "pending_id": unsent, "pending_email_sent": False},
        },
        prepared={unsent},
        created={"new@test.com": new_id},
    )
    load.assert_called_once()
    assert load.call_args.args[1] == [
        "member@test.com", "sent@test.com", "unsent@test.com", "new@test.com", "new@test.com",
    ]
    write.assert_called_once()
    assert write.call_args.kwargs["resend_ids"] == [unsent]
    assert write.call_args.kwargs["new_invites"] == [("new@test.com", "follower", None)]
    assert [(r["email"], r["status"], r["invitation_id"]) for r in results] == [
        ("member@test.com", "skipped_member", None),
        ("sent@test.com", "skipped_duplicate", sent),
        ("unsent@test.com", "resent", unsent),
        ("new@test.com", "created", new_id),
        ("new@test.com", "skipped_duplicate", None),
    ]
    assert [c.args[0] for c in pub.call_args_list] == [unsent, new_id]


def test_batch_invite_lost_insert_race_reports_duplicate():
    results, _, _, pub = _batch(["race@test.com"], targets={}, created={})
    assert results[0]["status"] == "skipped_duplicate"
    pub.assert_not_called()


def test_batch_invite_email_queue_failed_returns_row_not_raises():
    inv_id = uuid.uuid4()
    results, _, _, _ = _batch(
        ["a@test.com"],
        targets={},
        created={"a@test.com": inv_id},
        publish=RuntimeError("pubsub down"),
    )
    assert results == [
        {"email": "a@test.com", "status": "email_queue_failed", "invitation_id": inv_id}
    ]


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


def test_accept_invitation_idempotent_already_member():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.invitations.accept_invitation_by_token",
        return_value={
            "already_member": True,
            "baby_profile_id": baby_id,
            "role": "follower",
            "baby_name": "Parker",
        },
    ):
        result = accept_invitation("token", "uid-1", "a@test.com")
    assert result["already_member"] is True
    assert result["baby_profile_id"] == baby_id
