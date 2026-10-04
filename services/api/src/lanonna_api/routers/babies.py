from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status

from lanonna_api.auth import current_user
from lanonna_api.domain.avatar_urls import normalize_avatar_for_storage
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.domain.home import announce_arrival, build_home_summary, list_activity_events
from lanonna_api.repositories.babies import (
    create_baby_with_owner_membership,
    get_baby_for_owner,
    list_babies_for_user,
    update_baby_for_owner,
)
from lanonna_api.repositories.first_moment import seed_first_moment
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.schemas.babies import (
    BabyCreateRequest,
    BabySummary,
    BabyUpdateRequest,
    baby_summary_from_row,
)
from lanonna_api.schemas.home import HomeSummaryResponse
from lanonna_api.schemas.first_moment import (
    FirstMomentSeedRequest,
    FirstMomentSeedResponse,
)

router = APIRouter(prefix="/v1/babies", tags=["babies"])


@router.get("", response_model=list[BabySummary])
def list_babies(user: dict[str, Any] = Depends(current_user)) -> list[BabySummary]:
    upsert_app_user(user["uid"], user.get("email"))
    return [baby_summary_from_row(row) for row in list_babies_for_user(user["uid"])]


@router.post("", response_model=BabySummary, status_code=status.HTTP_201_CREATED)
def create_baby(
    body: BabyCreateRequest,
    user: dict[str, Any] = Depends(current_user),
) -> BabySummary:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        row = create_baby_with_owner_membership(
            user["uid"],
            body.name,
            body.gender,
            body.expected_birth_date,
            body.actual_birth_date,
            body.lifecycle_status,
        )
    except RuntimeError as exc:
        raise map_domain_errors(exc) from exc
    return baby_summary_from_row(row)


@router.patch("/{baby_profile_id}", response_model=BabySummary)
def patch_baby(
    baby_profile_id: uuid.UUID,
    body: BabyUpdateRequest,
    user: dict[str, Any] = Depends(current_user),
) -> BabySummary:
    upsert_app_user(user["uid"], user.get("email"))
    fields: dict[str, Any] = {}
    if body.name is not None:
        fields["name"] = body.name.strip()
    if body.gender is not None:
        fields["gender"] = body.gender
    if body.expected_birth_date is not None:
        fields["expected_birth_date"] = body.expected_birth_date
    if body.actual_birth_date is not None:
        fields["actual_birth_date"] = body.actual_birth_date
    if body.lifecycle_status is not None:
        fields["lifecycle_status"] = body.lifecycle_status
    if body.avatar_url is not None:
        try:
            fields["avatar_url"] = normalize_avatar_for_storage(body.avatar_url)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(exc),
            ) from exc

    announcing = body.lifecycle_status == "born" and body.actual_birth_date is not None
    try:
        if announcing:
            extra = {k: v for k, v in fields.items() if k not in ("lifecycle_status", "actual_birth_date")}
            row = announce_arrival(
                user["uid"],
                baby_profile_id,
                body.actual_birth_date,
                extra_fields=extra or None,
            )
        else:
            row = update_baby_for_owner(user["uid"], baby_profile_id, fields)
    except (ValueError, PermissionError) as exc:
        raise map_domain_errors(exc) from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Baby not found")
    return baby_summary_from_row(row)


@router.get("/{baby_profile_id}/home-summary", response_model=HomeSummaryResponse)
def home_summary(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> HomeSummaryResponse:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        data = build_home_summary(user["uid"], baby_profile_id)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    return HomeSummaryResponse(**data)


@router.get("/{baby_profile_id}/activity-events")
def activity_events(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
    limit: int = Query(default=20, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return list_activity_events(user["uid"], baby_profile_id, limit=limit, offset=offset)
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc


@router.post(
    "/{baby_profile_id}/onboarding/first-moment",
    response_model=FirstMomentSeedResponse,
)
def first_moment_seed(
    baby_profile_id: uuid.UUID,
    body: FirstMomentSeedRequest,
    user: dict[str, Any] = Depends(current_user),
) -> FirstMomentSeedResponse:
    upsert_app_user(user["uid"], user.get("email"))
    if get_baby_for_owner(user["uid"], baby_profile_id) is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner access required")
    try:
        counts = seed_first_moment(
            user["uid"],
            baby_profile_id,
            body.event_preset_ids,
            body.registry_preset_ids,
            [{"name": r.name, "gender": r.gender} for r in body.name_suggestions],
        )
    except PermissionError as exc:
        raise map_domain_errors(exc) from exc
    return FirstMomentSeedResponse(**counts)
