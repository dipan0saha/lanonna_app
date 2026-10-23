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
| Complete profile `_onBack` | Verified users go to login (sign-up path when OAuth); never push email-verify when already verified |
| Create-baby onboarding Back | When `profileComplete`, Back goes to login instead of complete profile |
| Email verify screen | On load, if already verified, `go(signedInResumeLocation)` instead of always complete profile |
| `redirectFor` | Drop `emailVerify` from the no-baby allow-set when profile is complete |
| `OnboardingSignOutButton` | Shared widget on setup screens (complete profile, create-baby, email verify) calling `AuthSessionService.signOut` |

## References

- GitHub #418, #409
- `onboarding_complete_profile_screen.dart`, `onboarding_email_verify_screen.dart`, `app_session.dart`
