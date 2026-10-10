from pydantic import BaseModel


class OnboardingStatusResponse(BaseModel):
    email_verified: bool
    profile_complete: bool
    has_owner_baby: bool
    has_baby_membership: bool
    owner_onboarding_completed: bool
    can_access_main_app: bool
