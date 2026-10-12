from unittest.mock import patch
import uuid

from lanonna_api.domain.search import search_baby_content


def test_search_empty_query_returns_empty_groups():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.search.require_active_membership",
        return_value={"role": "owner"},
    ):
        result = search_baby_content("uid", baby_id, "")
    assert result["query"] == ""
    assert result["photos"] == []


def test_search_requires_membership():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.search.require_active_membership",
        side_effect=PermissionError("Baby membership required."),
    ):
        try:
            search_baby_content("uid", baby_id, "test")
        except PermissionError:
            return
    raise AssertionError("expected PermissionError")


def test_search_escapes_ilike_wildcards_in_pattern():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.search.require_active_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.search.search_photos",
    ) as mock_photos, patch(
        "lanonna_api.domain.search.search_events",
        return_value=[],
    ), patch(
        "lanonna_api.domain.search.search_registry_items",
        return_value=[],
    ), patch(
        "lanonna_api.domain.search.search_name_suggestions",
        return_value=[],
    ):
        search_baby_content("uid", baby_id, "100%")
    pattern = mock_photos.call_args[0][1]
    assert pattern == r"%100\%%"


def test_search_membership_ended():
    import pytest

    from lanonna_api.domain.member_errors import MemberLifecycleError

    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.search.require_active_membership",
        side_effect=MemberLifecycleError(
            "membership_ended",
            "You no longer have access to this baby profile.",
        ),
    ):
        with pytest.raises(MemberLifecycleError) as exc:
            search_baby_content("uid", baby_id, "test")
    assert exc.value.code == "membership_ended"
