from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, status

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.http_errors import api_error, map_domain_errors
from lanonna_api.domain.data_export import latest_baby_data_export, request_baby_data_export

router = APIRouter(prefix="/v1/babies", tags=["data-export"])


@router.post("/{baby_profile_id}/data-export")
def create_data_export(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        return request_baby_data_export(user.uid, baby_profile_id)
    except (PermissionError, RuntimeError) as exc:
        raise map_domain_errors(exc) from exc


@router.get("/{baby_profile_id}/data-export/latest")
def get_latest_data_export(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> dict[str, Any]:
    try:
        job = latest_baby_data_export(user.uid, baby_profile_id)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    if job is None:
        raise api_error(status.HTTP_404_NOT_FOUND, ErrorCode.NOT_FOUND, "No export yet")
    return job
