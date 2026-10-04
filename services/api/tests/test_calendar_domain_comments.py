import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.calendar import edit_event_comment


def test_edit_event_comment_rejects_empty_body():
    baby_id = uuid.uuid4()
    event_id = uuid.uuid4()
    comment_id = uuid.uuid4()
    with patch("lanonna_api.domain.calendar.require_membership"), patch(
        "lanonna_api.domain.calendar.get_event",
        return_value={"title": "Party"},
    ):
        with pytest.raises(ValueError, match="Comment body required"):
            edit_event_comment("uid", baby_id, event_id, comment_id, "  ")


def test_edit_event_comment_event_not_found():
    baby_id = uuid.uuid4()
    event_id = uuid.uuid4()
    comment_id = uuid.uuid4()
    with patch("lanonna_api.domain.calendar.require_membership"), patch(
        "lanonna_api.domain.calendar.get_event",
        return_value=None,
    ):
        with pytest.raises(LookupError, match="Event not found"):
            edit_event_comment("uid", baby_id, event_id, comment_id, "Hi")


def test_edit_event_comment_not_found_when_update_returns_none():
    baby_id = uuid.uuid4()
    event_id = uuid.uuid4()
    comment_id = uuid.uuid4()
    with patch("lanonna_api.domain.calendar.require_membership"), patch(
        "lanonna_api.domain.calendar.get_event",
        return_value={"title": "Party"},
    ), patch(
        "lanonna_api.domain.calendar.update_event_comment",
        return_value=None,
    ):
        with pytest.raises(LookupError, match="Comment not found"):
            edit_event_comment("uid", baby_id, event_id, comment_id, "Updated")
