from typing import Any

from fastapi import APIRouter, Depends

from lanonna_api.auth import current_user
from lanonna_api.domain.onboarding import (
    complete_owner_onboarding_for_user,
    onboarding_status_for_user,
)
from lanonna_api.http_errors import map_domain_errors
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.schemas.onboarding import OnboardingStatusResponse

router = APIRouter(prefix="/v1/onboarding", tags=["onboarding"])


@router.get("/status", response_model=OnboardingStatusResponse)
def onboarding_status(
    user: dict[str, Any] = Depends(current_user),
) -> OnboardingStatusResponse:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        data = onboarding_status_for_user(
            user["uid"],
            email_verified=bool(user.get("email_verified", False)),
        )
    except LookupError as exc:
        raise map_domain_errors(exc) from exc
    return OnboardingStatusResponse(**data)


@router.post("/owner/complete", response_model=OnboardingStatusResponse)
def complete_owner_onboarding_route(
    user: dict[str, Any] = Depends(current_user),
) -> OnboardingStatusResponse:
    upsert_app_user(user["uid"], user.get("email"))
    try:
        data = complete_owner_onboarding_for_user(
            user["uid"],
            email_verified=bool(user.get("email_verified", False)),
        )
    except (LookupError, ValueError) as exc:
        raise map_domain_errors(exc) from exc
    return OnboardingStatusResponse(**data)
