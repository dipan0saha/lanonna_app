from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from lanonna_api.auth import current_user
from lanonna_api.domain.account import build_account_extensions
from lanonna_api.repositories.babies import list_babies_for_user
from lanonna_api.repositories.users import update_profile, upsert_app_user
from lanonna_api.schemas.babies import baby_summary_from_row
from lanonna_api.schemas.profile import ProfileResponse, ProfileUpdateRequest

router = APIRouter(prefix="/v1", tags=["profile"])


def _to_profile_response(row: dict[str, Any]) -> ProfileResponse:
    return ProfileResponse(
        firebase_uid=row["firebase_uid"],
        email=row.get("email"),
        display_name=row.get("display_name"),
        avatar_url=row.get("avatar_url"),
        owner_onboarding_completed=row.get("owner_onboarding_completed_at") is not None,
        created_at=row["created_at"].isoformat(),
        updated_at=row["updated_at"].isoformat(),
    )


@router.get("/me/account")
def get_account(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    row = upsert_app_user(user["uid"], user.get("email"))
    babies = list_babies_for_user(user["uid"])
    extensions = build_account_extensions(user["uid"])
    return {
        "profile": _to_profile_response(row).model_dump(),
        "babies": [
            baby_summary_from_row(b).model_dump(mode="json") for b in babies
        ],
        "engagement": extensions["engagement"],
        "storage_usage": extensions["storage_usage"],
    }


@router.get("/profile", response_model=ProfileResponse)
def get_profile(user: dict[str, Any] = Depends(current_user)) -> ProfileResponse:
    row = upsert_app_user(user["uid"], user.get("email"))
    return _to_profile_response(row)


@router.patch("/profile", response_model=ProfileResponse)
def patch_profile(
    body: ProfileUpdateRequest,
    user: dict[str, Any] = Depends(current_user),
) -> ProfileResponse:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        row = update_profile(
            user["uid"],
            body.display_name,
            avatar_url=body.avatar_url,
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    return _to_profile_response(row)
