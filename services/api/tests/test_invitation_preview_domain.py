import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from lanonna_api.domain.invitations import preview_invitation


def test_preview_invitation_accepted_status_includes_baby_fields():
    baby_id = uuid.uuid4()
    row = {
        "id": uuid.uuid4(),
        "baby_profile_id": baby_id,
        "invitee_email": "a@test.com",
        "role": "follower",
        "relationship_label": "Aunt",
        "status": "accepted",
        "expires_at": datetime.now(timezone.utc) + timedelta(days=1),
        "baby_name": "Parker",
        "lifecycle_status": "expecting",
        "expected_birth_date": None,
        "actual_birth_date": None,
        "inviter_display_name": "Sarah",
    }
    with patch(
        "lanonna_api.domain.invitations.fetch_invitation_preview_row",
        return_value=row,
    ):
        preview = preview_invitation("token")
    assert preview is not None
    assert preview["status"] == "accepted"
    assert preview["baby_profile_id"] == baby_id
    assert preview["baby_name"] == "Parker"


def test_preview_invitation_pending_expired_returns_expired():
    row = {
        "id": uuid.uuid4(),
        "baby_profile_id": uuid.uuid4(),
        "invitee_email": "a@test.com",
        "role": "follower",
        "relationship_label": None,
        "status": "pending",
        "expires_at": datetime.now(timezone.utc) - timedelta(hours=1),
        "baby_name": "Parker",
        "lifecycle_status": "expecting",
        "expected_birth_date": None,
        "actual_birth_date": None,
        "inviter_display_name": "Sarah",
    }
    with patch(
        "lanonna_api.domain.invitations.fetch_invitation_preview_row",
        return_value=row,
    ):
        preview = preview_invitation("token")
    assert preview == {"status": "expired"}
