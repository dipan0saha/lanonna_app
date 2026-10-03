from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status

from lanonna_api.auth import current_user
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.domain.search import search_baby_content
from lanonna_api.repositories.users import upsert_app_user

router = APIRouter(prefix="/v1/babies", tags=["search"])


@router.get("/{baby_profile_id}/search")
def search_baby(
    baby_profile_id: uuid.UUID,
    q: str = Query(default="", max_length=200),
    limit: int = Query(default=20, ge=1, le=50),
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return search_baby_content(user["uid"], baby_profile_id, q, limit=limit)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
