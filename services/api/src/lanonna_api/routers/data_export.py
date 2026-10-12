from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from lanonna_api.auth import current_app_user
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.domain.data_export import latest_baby_data_export, request_baby_data_export

router = APIRouter(prefix="/v1/babies", tags=["data-export"])


@router.post("/{baby_profile_id}/data-export")
def create_data_export(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        return request_baby_data_export(user["uid"], baby_profile_id)
    except (PermissionError, RuntimeError) as exc:
        raise map_domain_errors(exc) from exc


@router.get("/{baby_profile_id}/data-export/latest")
def get_latest_data_export(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        job = latest_baby_data_export(user["uid"], baby_profile_id)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No export yet")
    return job
