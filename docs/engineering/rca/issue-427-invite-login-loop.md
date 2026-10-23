# RCA: Invite login loops after sign-in (#427)

## Summary

An **existing** profile-complete account opening a follower/co-owner invite, tapping **Accept Invitation** → **Log in**, then signing in with email/password stays on the welcome-back login screen. Firebase and `GET /v1/onboarding/status` succeed, but **`POST /v1/invitations/accept` never runs**. Cold start while signed in can show the same login screen until the user backs out to the invite landing and accepts again.

Regression from PR #420 (#417): post-auth navigation uses `AppSession.signedInResumeLocation` as the single routing table.

## Root cause

1. **Resume path** — `OnboardingLoginScreen` sets `OnboardingStep.login` on mount. With a pending invite handoff, `shouldResumeInviteFlow` is true and `_inviteResumePath()` prefers `activeStep` over the invite landing, so it returns `OnboardingRoutes.login`.

2. **No redirect** — `signedInResumeLocation` returns that login path. In `redirectFor`, `canonical == path` yields no redirect, so a signed-in user remains on login.

3. **No accept** — `navigateAfterOnboardingAuth` only `context.go`s the resume location. Accept for profile-complete invitees lived in `navigateAfterCompleteProfile` (new-account path). Nothing calls `acceptSignedInInviteAndContinue` after invite login.

Before #420, incomplete routing sent this user to complete profile and accept ran there; profile-complete users were not stuck on login.

## Fix

| Layer | Change |
|-------|--------|
| `AppSession._inviteResumePath` | When server status is profile-complete, do not resume to `login` or `signup` steps; resume to the invite landing (same as handoff-only). Removes the signed-in login loop on cold start and redirect. |
| `navigateAfterOnboardingAuth` | After `refreshFromApi()`, if invite path + pending token + verified email + profile complete, call `acceptSignedInInviteAndContinue` (same accept path as the invite landing) instead of navigating to the auth entry route. |
| Tests | `app_session_redirect_test.dart`: login step + handoff + profile-complete → landing, not login. `onboarding_auth_navigation_test.dart`: invite login sign-in posts accept and leaves login. |

## References

- GitHub #427, #420, #417, #406, #418
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
- `apps/mobile/lib/features/onboarding/presentation/utils/onboarding_auth_navigation.dart`
- `apps/mobile/lib/features/onboarding/presentation/utils/invite_flow_navigation.dart`
