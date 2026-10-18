import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.baby_delete import (
    CannotDeleteSharedBabyError,
    delete_baby_profile,
)


def test_delete_sole_owned_baby():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.baby_delete.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.baby_delete.count_active_owners",
            return_value=1,
        ),
        patch(
            "lanonna_api.domain.baby_delete.soft_delete_baby_profiles",
        ) as soft_delete,
    ):
        delete_baby_profile("owner-1", baby_id)
    soft_delete.assert_called_once_with([baby_id])


def test_delete_shared_baby_refused():
    baby_id = uuid.uuid4()
    with (
        patch(
            "lanonna_api.domain.baby_delete.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.baby_delete.count_active_owners",
            return_value=2,
        ),
    ):
        with pytest.raises(CannotDeleteSharedBabyError) as exc:
            delete_baby_profile("owner-1", baby_id)
    assert exc.value.code.value == "cannot_delete_shared_baby"
