import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.registry import patch_item


def test_patch_purchased_item_denied():
    baby_id = uuid.uuid4()
    item_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.registry.assert_owner_membership",
    ), patch(
        "lanonna_api.domain.registry.item_has_purchase",
        return_value=True,
    ):
        with pytest.raises(PermissionError):
            patch_item("uid", baby_id, item_id, {"name": "X"})
