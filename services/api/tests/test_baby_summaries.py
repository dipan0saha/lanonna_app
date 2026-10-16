import uuid

from lanonna_api.domain.baby_summaries import baby_summary_from_row


def test_baby_summary_sets_closed_flags_from_lifecycle():
    baby_id = uuid.uuid4()
    summary = baby_summary_from_row(
        {
            "id": baby_id,
            "name": "River",
            "role": "owner",
            "lifecycle_status": "born",
            "can_leave": True,
        }
    )
    assert summary.names_closed is True
    assert summary.predictions_closed is True
