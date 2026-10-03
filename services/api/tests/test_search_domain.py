from unittest.mock import patch
import uuid

from lanonna_api.domain.search import search_baby_content


def test_search_empty_query_returns_empty_groups():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.search.get_baby_membership",
        return_value={"role": "owner"},
    ):
        result = search_baby_content("uid", baby_id, "")
    assert result["query"] == ""
    assert result["photos"] == []


def test_search_requires_membership():
    baby_id = uuid.uuid4()
    with patch("lanonna_api.domain.search.get_baby_membership", return_value=None):
        try:
            search_baby_content("uid", baby_id, "test")
        except PermissionError:
            return
    raise AssertionError("expected PermissionError")
