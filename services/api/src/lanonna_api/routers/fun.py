from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field

from lanonna_api.auth import current_user
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.domain import fun as fun_domain
from lanonna_api.repositories.users import upsert_app_user

router = APIRouter(
    prefix="/v1/babies/{baby_profile_id}/fun",
    tags=["fun"],
)


class NameCreate(BaseModel):
    suggested_name: str = Field(min_length=1)
    gender: str = Field(pattern="^(male|female)$")


class GenderVoteBody(BaseModel):
    gender: str = Field(pattern="^(male|female)$")
    is_anonymous: bool = True


class BirthdateVoteBody(BaseModel):
    predicted_birth_date: date
    is_anonymous: bool = True


class AnonymousPatch(BaseModel):
    is_anonymous: bool


@router.get("/names")
def list_names(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        return fun_domain.list_names(user["uid"], baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.post("/names", status_code=status.HTTP_201_CREATED)
def create_name(
    baby_profile_id: uuid.UUID,
    body: NameCreate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return fun_domain.suggest_name(
            user["uid"],
            baby_profile_id,
            body.suggested_name,
            body.gender,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.delete("/names/{suggestion_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_name(
    baby_profile_id: uuid.UUID,
    suggestion_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> Response:
    try:
        fun_domain.remove_suggestion(user["uid"], baby_profile_id, suggestion_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/names/{suggestion_id}/like")
def like_name(
    baby_profile_id: uuid.UUID,
    suggestion_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return fun_domain.toggle_like(user["uid"], baby_profile_id, suggestion_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.get("/predictions")
def get_predictions(
    baby_profile_id: uuid.UUID,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return fun_domain.get_predictions(user["uid"], baby_profile_id)
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.put("/predictions/gender")
def put_gender_vote(
    baby_profile_id: uuid.UUID,
    body: GenderVoteBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return fun_domain.set_gender_vote(
            user["uid"],
            baby_profile_id,
            body.gender,
            body.is_anonymous,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.put("/predictions/birthdate")
def put_birthdate_vote(
    baby_profile_id: uuid.UUID,
    body: BirthdateVoteBody,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return fun_domain.set_birthdate_vote(
            user["uid"],
            baby_profile_id,
            body.predicted_birth_date,
            body.is_anonymous,
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc


@router.patch("/predictions/anonymous")
def patch_anonymous(
    baby_profile_id: uuid.UUID,
    body: AnonymousPatch,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    try:
        return fun_domain.patch_anonymous(
            user["uid"], baby_profile_id, body.is_anonymous
        )
    except Exception as exc:
        raise map_domain_errors(exc) from exc
