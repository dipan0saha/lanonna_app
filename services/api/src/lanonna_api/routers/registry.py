from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field

from lanonna_api.auth import current_user
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.domain import registry as registry_domain
from lanonna_api.repositories.users import upsert_app_user

router = APIRouter(
    prefix="/v1/babies/{baby_profile_id}/registry",
    tags=["registry"],
)


class ItemCreate(BaseModel):
    name: str = Field(min_length=1)
    description: str | None = None
    product_url: str | None = None
    priority: int = Field(default=3, ge=1, le=5)
    catalog_suggestion_id: str | None = Field(default=None, max_length=64)


class ItemUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    product_url: str | None = None
    priority: int | None = Field(default=None, ge=1, le=5)


class ShippingPatch(BaseModel):
    address: str | None = None


@router.get("/items")
def list_items(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return registry_domain.list_items(user["uid"], baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post("/items", status_code=status.HTTP_201_CREATED)
def create_item(
    baby_profile_id: uuid.UUID,
    body: ItemCreate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return registry_domain.create_item(
            user["uid"],
            baby_profile_id,
            name=body.name,
            description=body.description,
            product_url=body.product_url,
            priority=body.priority,
            catalog_suggestion_id=body.catalog_suggestion_id,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.get("/items/{item_id}")
def get_item(
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return registry_domain.get_item(user["uid"], baby_profile_id, item_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.patch("/items/{item_id}")
def patch_item(
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
    body: ItemUpdate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return registry_domain.patch_item(
            user["uid"],
            baby_profile_id,
            item_id,
            body.model_dump(exclude_unset=True),
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    try:
        registry_domain.remove_item(user["uid"], baby_profile_id, item_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/items/{item_id}/purchase")
def claim_purchase(
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return registry_domain.claim_purchase(user["uid"], baby_profile_id, item_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.delete("/items/{item_id}/purchase", status_code=status.HTTP_204_NO_CONTENT)
def undo_purchase(
    baby_profile_id: uuid.UUID,
    item_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    try:
        registry_domain.undo_purchase(user["uid"], baby_profile_id, item_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/shipping-address")
def get_shipping(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return registry_domain.read_shipping(user["uid"], baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.patch("/shipping-address")
def patch_shipping(
    baby_profile_id: uuid.UUID,
    body: ShippingPatch,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return registry_domain.patch_shipping(
            user["uid"], baby_profile_id, body.address
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
