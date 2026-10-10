import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.membership_access import require_active_membership
from lanonna_api.http_errors import map_domain_errors


def test_require_active_membership_raises_membership_ended_for_tombstone():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.membership_access.get_baby_membership",
        return_value=None,
    ), patch(
        "lanonna_api.domain.membership_access.has_removed_membership",
        return_value=True,
    ):
        with pytest.raises(MemberLifecycleError) as exc:
            require_active_membership("uid", baby_id)
    assert exc.value.code == "membership_ended"


def test_membership_ended_maps_to_403_json():
    exc = MemberLifecycleError(
        "membership_ended",
        "You no longer have access to this baby profile.",
    )
    http_exc = map_domain_errors(exc)
    assert http_exc.status_code == 403
    assert http_exc.detail == {
        "error": "membership_ended",
        "message": "You no longer have access to this baby profile.",
    }
