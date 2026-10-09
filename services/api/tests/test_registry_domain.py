import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.registry import claim_purchase, create_item, patch_item
from lanonna_api.domain.url_validation import INVALID_HTTP_URL


def test_create_item_rejects_invalid_product_url():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.registry.assert_owner_membership",
    ), patch(
        "lanonna_api.domain.registry.create_registry_item",
    ) as create_mock:
        with pytest.raises(ValueError, match=INVALID_HTTP_URL):
            create_item(
                "uid",
                baby_id,
                name="Crib",
                description=None,
                product_url="not-a-url",
                priority=3,
                catalog_suggestion_id=None,
            )
        create_mock.assert_not_called()


def test_create_item_rejects_duplicate_catalog_suggestion():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.registry.assert_owner_membership",
    ), patch(
        "lanonna_api.domain.registry.catalog_suggestion_claimed",
        return_value=True,
    ), patch(
        "lanonna_api.domain.registry.create_registry_item",
    ) as create_mock:
        with pytest.raises(ValueError, match="already on the registry"):
            create_item(
                "uid",
                baby_id,
                name="Swaddle",
                description=None,
                product_url=None,
                priority=3,
                catalog_suggestion_id="swaddle_blankets",
            )
        create_mock.assert_not_called()


def test_create_item_passes_catalog_suggestion_id():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.registry.assert_owner_membership",
    ), patch(
        "lanonna_api.domain.registry.catalog_suggestion_claimed",
        return_value=False,
    ), patch(
        "lanonna_api.domain.registry.upsert_app_user",
    ), patch(
        "lanonna_api.domain.registry.insert_activity_event",
    ), patch(
        "lanonna_api.domain.registry.create_registry_item",
        return_value={
            "id": uuid.uuid4(),
            "name": "Swaddle",
            "description": "Soft",
            "product_url": None,
            "priority": 3,
            "catalog_suggestion_id": "swaddle_blankets",
        },
    ) as create_mock:
        out = create_item(
            "uid",
            baby_id,
            name="Swaddle",
            description="Soft",
            product_url=None,
            priority=3,
            catalog_suggestion_id="swaddle_blankets",
        )
        create_mock.assert_called_once()
        assert create_mock.call_args.kwargs["catalog_suggestion_id"] == "swaddle_blankets"
        assert out["catalog_suggestion_id"] == "swaddle_blankets"


def test_claim_purchase_follower_notifies_owners():
    baby_id = uuid.uuid4()
    item_id = uuid.uuid4()
    item_row = {"id": item_id, "name": "Car seat", "purchase_id": None}
    with patch(
        "lanonna_api.domain.registry.require_membership",
    ), patch(
        "lanonna_api.domain.registry.get_baby_membership",
        return_value={"role": "follower"},
    ), patch(
        "lanonna_api.domain.registry.get_registry_item",
        return_value=item_row,
    ), patch(
        "lanonna_api.domain.registry.upsert_app_user",
    ), patch(
        "lanonna_api.domain.registry.create_purchase",
    ), patch(
        "lanonna_api.domain.registry.insert_activity_event",
    ) as activity_mock, patch(
        "lanonna_api.domain.registry.actor_display_name",
        return_value="Aunt",
    ), patch(
        "lanonna_api.domain.registry.safe_enqueue_fan_out",
    ) as fan_out_mock:
        claim_purchase("follower_uid", baby_id, item_id)
        activity_mock.assert_called_once()
        assert activity_mock.call_args[0][3] == 'Someone is buying "Car seat"'
        spec = fan_out_mock.call_args[0][0]
        assert spec.recipient_mode == "baby_owners"
        assert spec.body == 'Aunt is buying "Car seat"'


def test_claim_purchase_owner_notifies_members():
    baby_id = uuid.uuid4()
    item_id = uuid.uuid4()
    item_row = {"id": item_id, "name": "Car seat", "purchase_id": None}
    with patch(
        "lanonna_api.domain.registry.require_membership",
    ), patch(
        "lanonna_api.domain.registry.get_baby_membership",
        return_value={"role": "owner"},
    ), patch(
        "lanonna_api.domain.registry.get_registry_item",
        return_value=item_row,
    ), patch(
        "lanonna_api.domain.registry.upsert_app_user",
    ), patch(
        "lanonna_api.domain.registry.create_purchase",
    ), patch(
        "lanonna_api.domain.registry.insert_activity_event",
    ) as activity_mock, patch(
        "lanonna_api.domain.registry.actor_display_name",
        return_value="Mom",
    ), patch(
        "lanonna_api.domain.registry.safe_enqueue_fan_out",
    ) as fan_out_mock:
        claim_purchase("owner_uid", baby_id, item_id)
        activity_mock.assert_called_once()
        assert activity_mock.call_args[0][3] == 'Marked "Car seat" as purchased'
        spec = fan_out_mock.call_args[0][0]
        assert spec.recipient_mode == "baby_members"
        assert spec.body == 'Mom marked "Car seat" as purchased'


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
