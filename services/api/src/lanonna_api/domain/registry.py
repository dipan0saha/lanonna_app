from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.errors import ErrorCode, ForbiddenError, InvalidInputError
from lanonna_api.domain import assert_owner_membership
from lanonna_api.domain.catalog_suggestion_ids import normalize_catalog_suggestion_id
from lanonna_api.domain.url_validation import normalize_optional_http_url
from lanonna_api.domain.gallery import require_membership
from lanonna_activity_copy import ActivityEventType, NotificationKind
from lanonna_activity_copy import params
from lanonna_api.domain.users_display import purchaser_display_name_from_row
from lanonna_api.domain.notifications import (
    FanOutSpec,
    NotificationChannel,
    safe_enqueue_fan_out,
)
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.domain.registry_shipping import (
    shipping_is_empty,
    shipping_response_from_row,
    validate_shipping_patch,
)
from lanonna_api.repositories.registry import (
    catalog_suggestion_claimed,
    create_purchase,
    create_registry_item,
    delete_purchase,
    delete_registry_item,
    get_purchase,
    get_registry_item,
    get_shipping_address_row,
    item_has_purchase,
    list_registry_items,
    update_registry_item,
    update_shipping_address_fields,
)


def _item_json(row: dict[str, Any]) -> dict[str, Any]:
    purchased = row.get("purchase_id") is not None
    purchase = None
    if purchased:
        purchase = {
            "purchased_by_firebase_uid": row.get("purchased_by_firebase_uid"),
            "purchaser_display_name": purchaser_display_name_from_row(row),
            "purchased_at": row["purchased_at"].isoformat()
            if row.get("purchased_at") and hasattr(row["purchased_at"], "isoformat")
            else None,
        }
    return {
        "id": str(row["id"]),
        "name": row["name"],
        "description": row.get("description"),
        "product_url": row.get("product_url"),
        "priority": row["priority"],
        "catalog_suggestion_id": row.get("catalog_suggestion_id"),
        "is_purchased": purchased,
        "purchase": purchase,
    }


def list_items(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    limit: int,
    offset: int,
) -> list[dict[str, Any]]:
    require_membership(firebase_uid, baby_profile_id)
    rows = list_registry_items(baby_profile_id, limit=limit, offset=offset)
    return [_item_json(r) for r in rows]


def get_item(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    row = get_registry_item(baby_profile_id, item_id)
    if row is None:
        raise LookupError("Registry item not found.")
    return _item_json(row)


def create_item(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    name: str,
    description: str | None,
    product_url: str | None,
    priority: int,
    catalog_suggestion_id: str | None = None,
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    if not name.strip():
        raise InvalidInputError(ErrorCode.ITEM_NAME_REQUIRED, "Item name is required.")
    product_url = normalize_optional_http_url(product_url)
    priority = max(1, min(5, priority))
    catalog_id = normalize_catalog_suggestion_id(catalog_suggestion_id)
    if catalog_id and catalog_suggestion_claimed(baby_profile_id, catalog_id):
        raise InvalidInputError(ErrorCode.ALREADY_ON_REGISTRY, "This suggestion is already on the registry.")
    row = create_registry_item(
        baby_profile_id,
        firebase_uid,
        name=name,
        description=description,
        product_url=product_url,
        priority=priority,
        catalog_suggestion_id=catalog_id,
    )
    insert_activity_event(
        baby_profile_id,
        firebase_uid,
        ActivityEventType.REGISTRY_ITEM_ADDED,
        {params.ITEM_NAME: row["name"]},
        {"registry_item_id": str(row["id"])},
    )
    return {
        "id": str(row["id"]),
        "name": row["name"],
        "description": row.get("description"),
        "product_url": row.get("product_url"),
        "priority": row["priority"],
        "catalog_suggestion_id": row.get("catalog_suggestion_id"),
        "is_purchased": False,
        "purchase": None,
    }


def patch_item(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
    fields: dict[str, Any],
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    if item_has_purchase(item_id):
        raise ForbiddenError(ErrorCode.REGISTRY_ITEM_PURCHASED, "Cannot edit a purchased registry item.")
    if "product_url" in fields:
        fields["product_url"] = normalize_optional_http_url(fields["product_url"])
    if "priority" in fields and fields["priority"] is not None:
        fields["priority"] = max(1, min(5, int(fields["priority"])))
    row = update_registry_item(baby_profile_id, item_id, fields)
    if row is None:
        raise LookupError("Registry item not found.")
    return get_item(firebase_uid, baby_profile_id, item_id)


def remove_item(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
) -> None:
    assert_owner_membership(firebase_uid, baby_profile_id)
    if not delete_registry_item(baby_profile_id, item_id):
        raise LookupError("Registry item not found.")


def claim_purchase(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
) -> dict[str, Any]:
    membership = require_membership(firebase_uid, baby_profile_id)
    is_owner = membership["role"] == "owner"
    item = get_registry_item(baby_profile_id, item_id)
    if item is None:
        raise LookupError("Registry item not found.")
    if item.get("purchase_id"):
        if item.get("purchased_by_firebase_uid") == firebase_uid:
            return {"status": "already_claimed"}
        raise ForbiddenError(ErrorCode.REGISTRY_ITEM_PURCHASED, "This item is already purchased.")
    purchase = create_purchase(item_id, firebase_uid)
    if purchase["purchased_by_firebase_uid"] != firebase_uid:
        raise ForbiddenError(ErrorCode.REGISTRY_ITEM_PURCHASED, "This item is already purchased.")
    # An owner marking an item purchased tells every member and is named in the
    # feed; a follower's claim tells only the owners and stays anonymous in the
    # feed so the gift remains a surprise to other followers.
    display_params = {params.ITEM_NAME: item["name"]}
    insert_activity_event(
        baby_profile_id,
        firebase_uid,
        ActivityEventType.REGISTRY_PURCHASED if is_owner else ActivityEventType.REGISTRY_CLAIMED,
        display_params,
        {"registry_item_id": str(item_id)},
    )
    fan_out = FanOutSpec(
        baby_profile_id=baby_profile_id,
        kind=NotificationKind.REGISTRY_PURCHASED if is_owner else NotificationKind.REGISTRY_BUYING,
        params=display_params,
        deep_link="/registry",
        actor_firebase_uid=firebase_uid,
        recipient_mode="baby_members" if is_owner else "baby_owners",
        exclude_firebase_uid=firebase_uid,
        notification_channel=NotificationChannel.REGISTRY,
    )
    safe_enqueue_fan_out(fan_out)
    return {"status": "claimed"}


def undo_purchase(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
) -> None:
    membership = require_membership(firebase_uid, baby_profile_id)
    purchase = get_purchase(item_id)
    if purchase is None:
        raise LookupError("No purchase on this item.")
    is_owner = membership["role"] == "owner"
    is_buyer = purchase["purchased_by_firebase_uid"] == firebase_uid
    if not is_owner and not is_buyer:
        raise PermissionError("Cannot undo this purchase.")
    delete_purchase(item_id)


def read_shipping(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    row = get_shipping_address_row(baby_profile_id)
    return shipping_response_from_row(row)


def patch_shipping(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    patch: dict[str, str | None],
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    fields = {
        "line1": patch.get("line1"),
        "line2": patch.get("line2"),
        "city": patch.get("city"),
        "region": patch.get("region"),
        "postal_code": patch.get("postal_code"),
        "country_code": patch.get("country_code"),
    }
    validate_shipping_patch(fields)
    if shipping_is_empty(fields):
        update_shipping_address_fields(
            baby_profile_id,
            line1=None,
            line2=None,
            city=None,
            region=None,
            postal_code=None,
            country_code=None,
        )
    else:
        update_shipping_address_fields(
            baby_profile_id,
            line1=fields["line1"],
            line2=fields.get("line2"),
            city=fields["city"],
            region=fields.get("region"),
            postal_code=fields["postal_code"],
            country_code=fields["country_code"],
        )
    row = get_shipping_address_row(baby_profile_id)
    return shipping_response_from_row(row)
