import uuid

from lanonna_api.domain.baby_summaries import baby_summary_from_row


def test_baby_summary_sets_closed_flags_from_lifecycle():
    baby_id = uuid.uuid4()
    summary = baby_summary_from_row(
        {
            "id": baby_id,
            "name": "River",
            "gender": "unknown",
            "role": "owner",
            "lifecycle_status": "born",
            "active_owner_count": 2,
        }
    )
    assert summary.names_closed is True
    assert summary.predictions_closed is True


def _row(role: str, owners: int) -> dict:
    return {
        "id": uuid.uuid4(),
        "name": "River",
        "gender": "female",
        "role": role,
        "lifecycle_status": "expecting",
        "active_owner_count": owners,
    }


def test_can_leave_comes_from_active_owner_count_on_the_row():
    assert baby_summary_from_row(_row("owner", 1)).can_leave is False
    assert baby_summary_from_row(_row("owner", 2)).can_leave is True
    assert baby_summary_from_row(_row("follower", 1)).can_leave is True


def test_unnamed_baby_summary_has_null_name():
    row = _row("owner", 1) | {"name": None}
    assert baby_summary_from_row(row).name is None
