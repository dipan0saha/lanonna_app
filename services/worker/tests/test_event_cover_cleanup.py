import uuid
from unittest.mock import MagicMock, patch

import pytest

from lanonna_worker.event_cover_cleanup import (
    EventCoverPurgeIncomplete,
    purge_stale_unreferenced_event_covers,
)


def test_one_failure_does_not_stop_the_rest_and_fails_the_run():
    ids = [uuid.uuid4(), uuid.uuid4(), uuid.uuid4()]
    with (
        patch(
            "lanonna_worker.event_cover_cleanup._stale_cover_ids", return_value=ids
        ),
        patch(
            "lanonna_worker.event_cover_cleanup._purge_one",
            side_effect=[True, RuntimeError("gcs"), False],
        ) as purge_one,
    ):
        with pytest.raises(EventCoverPurgeIncomplete):
            purge_stale_unreferenced_event_covers(24)
    assert [c.args[0] for c in purge_one.call_args_list] == ids


def test_returns_removed_count():
    with (
        patch(
            "lanonna_worker.event_cover_cleanup._stale_cover_ids",
            return_value=[uuid.uuid4(), uuid.uuid4()],
        ) as stale,
        patch(
            "lanonna_worker.event_cover_cleanup._purge_one",
            side_effect=[True, False],
        ),
    ):
        assert purge_stale_unreferenced_event_covers(24, limit=10) == 1
    stale.assert_called_once_with(24, 10)
