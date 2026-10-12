import pytest
from pydantic import ValidationError

from lanonna_api.input_limits import MAX_FUN_SUGGESTED_NAME_LEN
from lanonna_api.routers.fun import NameCreate


def test_name_create_rejects_oversized_suggested_name():
    with pytest.raises(ValidationError):
        NameCreate(
            suggested_name="x" * (MAX_FUN_SUGGESTED_NAME_LEN + 1),
            gender="male",
        )
