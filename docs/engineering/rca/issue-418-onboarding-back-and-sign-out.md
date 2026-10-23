# RCA: Onboarding back loop and no sign-out (#418)

## Summary

From create-baby, Back opened **Complete your profile**; Back again briefly showed **Check your email** for an already-verified user, then bounced back to complete profile. No onboarding step offered sign-out for a signed-in user with no baby.

## Root cause

1. **Back stack vs routing table** — `OnboardingCompleteProfileScreen._onBack` always navigated to `emailVerify` when `!skipEmailVerify`, even if Firebase already had `emailVerified == true`. `OnboardingEmailVerifyScreen` polls verification and immediately `go(completeProfile)`, producing a flash. `redirectFor` allowed `emailVerify` in the no-baby allow-set even when profile was complete, so the loop was stable.

2. **Create-baby Back** — Always returned to complete profile, which is wrong when the profile is already complete (user only needs create-baby).

3. **Sign-out** — Onboarding chrome had no hook to `AuthSessionService.signOut`.

## Fix

| Layer | Change |
|-------|--------|
| `AppSession.redirectFor` | One table rule: a signed-in user on `emailVerify` who is verified (or skips verification, OAuth) is redirected to the resume step. `emailVerify` was removed from the profile-incomplete, no-baby and post-baby allow-sets, so no state can render it for a verified user. |
| `AppSession.allowsSignedInLocation` | Asks the same table whether a location is reachable. |
| `onboardingBackAllowed` | Shared helper: setup screens show Back only when its target is allowed for the current session, so Back can never open a screen the router would reject (no flash). Per-screen login special cases from the first draft were reverted; Back targets stay the natural previous step. |
| Email verify screen | Checks once on load and on each poll; once verified it refreshes the session and goes to `signedInResumeLocation` instead of a hard-coded Complete profile. |
| `OnboardingSignOutButton` | Shared widget on setup screens (complete profile, create-baby, email verify) calling `AuthSessionService.signOut`; uses the shared `authSignOut` string (also used by the biometric lock). |
| Tests | `app_session_redirect_test.dart`: verified user on email verify redirects for every no-main-app state; Back targets follow the table |

## References

- GitHub #418, #409
- `onboarding_complete_profile_screen.dart`, `onboarding_email_verify_screen.dart`, `app_session.dart`
