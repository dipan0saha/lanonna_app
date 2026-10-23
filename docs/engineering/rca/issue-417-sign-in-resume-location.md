# RCA: Sign-in lands on Complete profile instead of create-baby (#417)

## Summary

An email-verified user with `profile_complete: true` and no baby memberships who signed in via the welcome carousel → login was sent to **Complete your profile** instead of **Create your baby's profile**. Cold start for the same session correctly used `AppSession.signedInResumeLocation` → create-baby (fixed in #409 / PR #405).

## Root cause

`navigateAfterOnboardingAuth` (`onboarding_auth_navigation.dart`) refreshed onboarding status from the API but ignored `profileComplete`. Any session with `!canAccessMainApp` was hard-coded to `OnboardingRoutes.completeProfile` after the sign-up-only email-verify branch. Login therefore disagreed with the single routing table in `AppSession.signedInResumeLocation`.

## Fix

| Layer | Change |
|-------|--------|
| `navigateAfterOnboardingAuth` | After `refreshFromApi()`, navigate with `context.go(session.signedInResumeLocation(emailVerified: …))` (same table as cold start / redirect). `emailVerified` comes from `AuthRepository.currentUser`; the unused `isSignUp` flag and the sign-up-only email-verify branch were removed, so sign-up and login share one path. |
| Tests | `onboarding_auth_navigation_test.dart`: verified vs unverified sign-in lands where cold start would; profile-complete, no-baby sign-in matches the cold-start resume location |

## References

- GitHub #417, #409, PR #405
- `apps/mobile/lib/features/onboarding/presentation/utils/onboarding_auth_navigation.dart`
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
