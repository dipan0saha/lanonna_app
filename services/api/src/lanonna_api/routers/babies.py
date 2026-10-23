from __future__ import annotations

import uuid
from typing import Any, Literal

from fastapi import APIRouter, Depends, Query, Response, status

from lanonna_api.domain.errors import ErrorCode
from lanonna_api.auth import AppUser, current_app_user
from lanonna_api.domain.avatar_urls import normalize_avatar_for_storage
from lanonna_api.http_errors import api_error, map_domain_errors
from lanonna_api.domain.baby_delete import delete_baby_profile
from lanonna_api.domain.baby_update import update_baby_profile
from lanonna_api.domain.home import announce_arrival, build_home_summary, list_activity_events
from lanonna_api.repositories.babies import (
    create_baby_with_owner_membership,
    list_babies_for_user,
)
from lanonna_api.domain.onboarding import seed_expecting_profile_name_suggestions, seed_first_moment
from lanonna_api.domain.baby_summaries import baby_summaries_from_rows, baby_summary_from_row
from lanonna_api.schemas.babies import (
    BabyCreateRequest,
    BabySummary,
    BabyUpdateRequest,
    normalize_baby_name,
)
from lanonna_api.schemas.home import HomeSummaryResponse
from lanonna_api.schemas.first_moment import (
    FirstMomentSeedRequest,
    FirstMomentSeedResponse,
)
from lanonna_api.pagination import offset_page_from_extra_row

router = APIRouter(prefix="/v1/babies", tags=["babies"])


@router.get("")
def list_babies(
    user: AppUser = Depends(current_app_user),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    rows = list_babies_for_user(user.uid, limit=limit + 1, offset=offset)
    page = offset_page_from_extra_row(rows, offset=offset, limit=limit)
    page["items"] = [
        summary.model_dump(mode="json")
        for summary in baby_summaries_from_rows(page["items"])
    ]
    return page


@router.post("", response_model=BabySummary, status_code=status.HTTP_201_CREATED)
def create_baby(
    body: BabyCreateRequest,
    user: AppUser = Depends(current_app_user),
) -> BabySummary:
    if body.profile_name_suggestions and body.lifecycle_status != "expecting":
        raise api_error(status.HTTP_400_BAD_REQUEST, ErrorCode.INVALID_REQUEST, "profile_name_suggestions are only allowed for expecting babies.")
    try:
        row = create_baby_with_owner_membership(
            user.uid,
            body.name,
            body.gender,
            body.expected_birth_date,
            body.actual_birth_date,
            body.lifecycle_status,
            body.relationship_label,
        )
    except RuntimeError as exc:
        raise map_domain_errors(exc) from exc
    if body.profile_name_suggestions:
        seed_expecting_profile_name_suggestions(
            user.uid,
            row["id"],
            [{"name": r.name, "gender": r.gender} for r in body.profile_name_suggestions],
            baby=row,
        )
    return baby_summary_from_row(row)


@router.patch("/{baby_profile_id}", response_model=BabySummary)
def patch_baby(
    baby_profile_id: uuid.UUID,
    body: BabyUpdateRequest,
    user: AppUser = Depends(current_app_user),
) -> BabySummary:
    fields: dict[str, Any] = {}
    if body.name is not None:
        fields["name"] = normalize_baby_name(body.name)
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
            raise map_domain_errors(exc) from exc

    suggestions = body.profile_name_suggestions
    if suggestions and body.lifecycle_status == "born":
        raise api_error(status.HTTP_400_BAD_REQUEST, ErrorCode.INVALID_REQUEST, "profile_name_suggestions are only allowed for expecting babies.")

    announcing = body.lifecycle_status == "born" and body.actual_birth_date is not None
    try:
        if announcing:
            extra = {k: v for k, v in fields.items() if k not in ("lifecycle_status", "actual_birth_date")}
            row = announce_arrival(
                user.uid,
                baby_profile_id,
                body.actual_birth_date,
                extra_fields=extra or None,
            )
        else:
            row = update_baby_profile(user.uid, baby_profile_id, fields)
    except (ValueError, PermissionError) as exc:
        raise map_domain_errors(exc) from exc

    if suggestions:
        lifecycle = row.get("lifecycle_status") or "expecting"
        if lifecycle != "expecting":
            raise api_error(status.HTTP_400_BAD_REQUEST, ErrorCode.INVALID_REQUEST, "profile_name_suggestions are only allowed for expecting babies.")
        seed_expecting_profile_name_suggestions(
            user.uid,
            baby_profile_id,
            [{"name": r.name, "gender": r.gender} for r in suggestions],
            baby=row,
        )

    return baby_summary_from_row(row)


@router.delete(
    "/{baby_profile_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_baby(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> Response:
    try:
        delete_baby_profile(user.uid, baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{baby_profile_id}/home-summary", response_model=HomeSummaryResponse)
def home_summary(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
) -> HomeSummaryResponse:
    try:
        data = build_home_summary(user.uid, baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return HomeSummaryResponse(**data)


@router.get("/{baby_profile_id}/activity-events")
def activity_events(
    baby_profile_id: uuid.UUID,
    user: AppUser = Depends(current_app_user),
    limit: int = Query(default=20, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
    scope: Literal["all", "gallery"] = Query(default="all"),
) -> dict[str, Any]:
    try:
        return list_activity_events(
            user.uid,
            baby_profile_id,
            limit=limit,
            offset=offset,
            scope=scope,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post(
    "/{baby_profile_id}/onboarding/first-moment",
    response_model=FirstMomentSeedResponse,
)
def first_moment_seed(
    baby_profile_id: uuid.UUID,
    body: FirstMomentSeedRequest,
    user: AppUser = Depends(current_app_user),
) -> FirstMomentSeedResponse:
    try:
        counts = seed_first_moment(
            user.uid,
            baby_profile_id,
            body.event_preset_ids,
            body.registry_preset_ids,
            [{"name": r.name, "gender": r.gender} for r in body.name_suggestions],
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return FirstMomentSeedResponse(**counts)
