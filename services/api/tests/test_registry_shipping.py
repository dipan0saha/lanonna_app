import uuid
from unittest.mock import patch

import pytest

from lanonna_api.domain.registry_shipping import (
    format_shipping_address,
    shipping_is_empty,
    validate_shipping_patch,
)
from lanonna_api.domain.registry import patch_shipping, read_shipping


def test_format_shipping_address_full():
    formatted = format_shipping_address(
        {
            "line1": "123 Main St",
            "line2": "Apt 4B",
            "city": "Springfield",
            "region": "IL",
            "postal_code": "62704",
            "country_code": "US",
        }
    )
    assert formatted is not None
    assert "123 Main St" in formatted
    assert "Apt 4B" in formatted
    assert "Springfield, IL 62704" in formatted
    assert "US" in formatted or "United States" in formatted


def test_format_shipping_address_empty():
    assert format_shipping_address(
        {
            "line1": None,
            "line2": None,
            "city": None,
            "region": None,
            "postal_code": None,
            "country_code": None,
        }
    ) is None


def test_validate_shipping_patch_rejects_partial():
    with pytest.raises(ValueError, match="line1, city, postal_code"):
        validate_shipping_patch(
            {
                "line1": "123 Main",
                "line2": None,
                "city": None,
                "region": None,
                "postal_code": None,
                "country_code": None,
            }
        )


def test_validate_shipping_patch_allows_clear():
    validate_shipping_patch(
        {
            "line1": None,
            "line2": None,
            "city": None,
            "region": None,
            "postal_code": None,
            "country_code": None,
        }
    )
    assert shipping_is_empty(
        {
            "line1": None,
            "line2": None,
            "city": None,
            "region": None,
            "postal_code": None,
            "country_code": None,
        }
    )


def test_read_shipping_returns_structured():
    baby_id = uuid.uuid4()
    row = {
        "registry_shipping_line1": "123 QA Lane",
        "registry_shipping_line2": None,
        "registry_shipping_city": "Austin",
        "registry_shipping_region": "TX",
        "registry_shipping_postal_code": "78701",
        "registry_shipping_country_code": "US",
    }
    with patch(
        "lanonna_api.domain.registry.require_membership",
    ), patch(
        "lanonna_api.domain.registry.get_shipping_address_row",
        return_value=row,
    ):
        data = read_shipping("uid", baby_id)
    assert data["line1"] == "123 QA Lane"
    assert data["city"] == "Austin"
    assert data["formatted"]


def test_patch_shipping_clears_address():
    baby_id = uuid.uuid4()
    with patch(
        "lanonna_api.domain.registry.assert_owner_membership",
    ), patch(
        "lanonna_api.domain.registry.update_shipping_address_fields",
    ) as update, patch(
        "lanonna_api.domain.registry.get_shipping_address_row",
        return_value={
            "registry_shipping_line1": None,
            "registry_shipping_line2": None,
            "registry_shipping_city": None,
            "registry_shipping_region": None,
            "registry_shipping_postal_code": None,
            "registry_shipping_country_code": None,
        },
    ):
        result = patch_shipping(
            "uid",
            baby_id,
            {
                "line1": None,
                "line2": None,
                "city": None,
                "region": None,
                "postal_code": None,
                "country_code": None,
            },
        )
    update.assert_called_once()
    assert result["formatted"] is None
