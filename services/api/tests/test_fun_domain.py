import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.fun import suggest_name


def test_follower_name_limit_per_gender():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.fun.get_baby_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.fun.count_suggestions_by_author_gender",
        return_value=1,
    ):
        with pytest.raises(PermissionError):
            suggest_name("uid", baby_id, "Alex", "male")


def test_suggest_name_rejects_case_insensitive_duplicate():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.fun.require_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.fun.get_baby_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.fun.find_name_suggestion_case_insensitive",
        return_value={"id": uuid.uuid4(), "suggested_name": "James", "gender": "male"},
    ):
        with pytest.raises(ValueError, match="already on the list"):
            suggest_name("uid", baby_id, "james", "male")
