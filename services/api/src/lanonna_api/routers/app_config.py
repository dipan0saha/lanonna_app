from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Query, status
from pydantic import BaseModel

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.http_errors import api_error
from lanonna_api.repositories.app_versions import get_app_version_requirement

router = APIRouter(prefix="/v1/app", tags=["app"])


class AppVersionResponse(BaseModel):
    platform: Literal["android", "ios"]
    minimum_version: str
    store_url: str


@router.get("/version", response_model=AppVersionResponse)
def app_version_requirement(
    platform: Literal["android", "ios"] = Query(...),
) -> AppVersionResponse:
    row = get_app_version_requirement(platform)
    if row is None:
        raise api_error(status.HTTP_404_NOT_FOUND, ErrorCode.NOT_FOUND, "Unknown platform")
    return AppVersionResponse(
        platform=row["platform"],
        minimum_version=row["minimum_version"],
        store_url=row["store_url"],
    )
