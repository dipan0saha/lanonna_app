from unittest.mock import patch

from lanonna_api.domain.account_delete import delete_account_eligibility


def test_eligibility_allowed_when_no_sole_owned_babies():
    with patch(
        "lanonna_api.domain.account_delete._sole_owned_baby_ids",
        return_value=[],
    ):
        result = delete_account_eligibility("uid")
    assert result["allowed"] is True
    assert result["blockers"] == []
