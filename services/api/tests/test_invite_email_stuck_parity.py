"""The owner's Resend appears exactly when the worker would re-claim a stuck send."""

import re
from pathlib import Path

from lanonna_api.repositories.invitations import INVITE_EMAIL_STUCK_MINUTES

_WORKER = (
    Path(__file__).resolve().parents[2]
    / "worker/src/lanonna_worker/invite_email.py"
)


def test_stuck_window_matches_worker_claim_timeout():
    match = re.search(r"^_CLAIM_STALE_MINUTES = (\d+)$", _WORKER.read_text(), re.M)
    assert match is not None
    assert int(match.group(1)) == INVITE_EMAIL_STUCK_MINUTES
