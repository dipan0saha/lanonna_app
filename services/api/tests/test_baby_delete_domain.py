import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.baby_delete import (
    CannotDeleteSharedBabyError,
    delete_baby_profile,
)
from lanonna_api.repositories.baby_profile_delete import SoleOwnerDeleteOutcome


def _delete_with(outcome: SoleOwnerDeleteOutcome, baby_id: uuid.UUID):
    with (
        patch(
            "lanonna_api.domain.baby_delete.require_owner_baby",
            return_value={"id": baby_id},
        ),
        patch(
            "lanonna_api.domain.baby_delete.soft_delete_baby_profile_if_sole_owner",
            return_value=outcome,
        ) as repo,
        patch("lanonna_api.domain.baby_delete.get_connection") as mock_conn,
        patch(
            "lanonna_api.domain.baby_delete.collect_and_delete_baby_export_jobs",
            return_value=[],
        ),
        patch(
            "lanonna_api.domain.baby_delete.create_baby_profile_storage_cleanup_job",
            return_value=uuid.uuid4(),
        ),
        patch("lanonna_api.domain.baby_delete._safe_publish_storage_cleanup"),
    ):
        mock_conn.return_value.__enter__.return_value = object()
        delete_baby_profile("owner-1", baby_id)
    return repo


def test_delete_sole_owned_baby():
    baby_id = uuid.uuid4()
    repo = _delete_with(SoleOwnerDeleteOutcome.DELETED, baby_id)
    repo.assert_called_once_with(baby_id, "owner-1")


def test_delete_shared_baby_refused():
    with pytest.raises(CannotDeleteSharedBabyError) as exc:
        _delete_with(SoleOwnerDeleteOutcome.SHARED, uuid.uuid4())
    assert exc.value.code.value == "cannot_delete_shared_baby"


def test_delete_after_losing_ownership_is_forbidden():
    with pytest.raises(PermissionError):
        _delete_with(SoleOwnerDeleteOutcome.NOT_OWNER, uuid.uuid4())
