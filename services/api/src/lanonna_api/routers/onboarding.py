from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from lanonna_api.auth import current_user
from lanonna_api.repositories.users import (
    complete_owner_onboarding,
    get_app_user,
    upsert_app_user,
    user_has_baby_membership,
    user_has_owner_baby,
)
from lanonna_api.schemas.onboarding import OnboardingStatusResponse

router = APIRouter(prefix="/v1/onboarding", tags=["onboarding"])


@router.get("/status", response_model=OnboardingStatusResponse)
def onboarding_status(
    user: dict[str, Any] = Depends(current_user),
) -> OnboardingStatusResponse:
    upsert_app_user(user["uid"], user.get("email"))
    row = get_app_user(user["uid"])
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    display_name = row.get("display_name")
    return OnboardingStatusResponse(
        email_verified=bool(user.get("email_verified", False)),
        profile_complete=bool(display_name and str(display_name).strip()),
        has_owner_baby=user_has_owner_baby(user["uid"]),
        has_baby_membership=user_has_baby_membership(user["uid"]),
        owner_onboarding_completed=row.get("owner_onboarding_completed_at") is not None,
    )


@router.post("/owner/complete", response_model=OnboardingStatusResponse)
def complete_owner_onboarding_route(
    user: dict[str, Any] = Depends(current_user),
) -> OnboardingStatusResponse:
    upsert_app_user(user["uid"], user.get("email"))
    row = get_app_user(user["uid"])
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if not row.get("display_name"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Complete your profile before finishing onboarding.",
        )
    if not user_has_owner_baby(user["uid"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Create a baby profile before finishing onboarding.",
        )
    if not user.get("email_verified", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verify your email before finishing onboarding.",
        )

    complete_owner_onboarding(user["uid"])
    return onboarding_status(user)
