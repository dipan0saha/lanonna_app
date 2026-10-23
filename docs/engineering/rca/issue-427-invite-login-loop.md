# RCA: Invite login loops after sign-in (#427)

## Summary

An **existing** profile-complete account opening a follower/co-owner invite, tapping **Accept Invitation** → **Log in**, then signing in with email/password stays on the welcome-back login screen. Firebase and `GET /v1/onboarding/status` succeed, but **`POST /v1/invitations/accept` never runs**. Cold start while signed in can show the same login screen until the user backs out to the invite landing and accepts again.

Regression from PR #420 (#417): post-auth navigation uses `AppSession.signedInResumeLocation` as the single routing table.

## Root cause

1. **Resume path** — `OnboardingLoginScreen` sets `OnboardingStep.login` on mount. With a pending invite handoff, `shouldResumeInviteFlow` is true and `_inviteResumePath()` prefers `activeStep` over the invite landing, so it returns `OnboardingRoutes.login`.

2. **No redirect** — `signedInResumeLocation` returns that login path. In `redirectFor`, `canonical == path` yields no redirect, so a signed-in user remains on login.

3. **No accept** — `navigateAfterOnboardingAuth` only `context.go`s the resume location. Accept for profile-complete invitees lived in `navigateAfterCompleteProfile` (new-account path). Nothing calls `acceptSignedInInviteAndContinue` after invite login.

Before #420, incomplete routing sent this user to complete profile and accept ran there; profile-complete users were not stuck on login.

4. **Owner sync drops the token** — `syncCompletedFromServer(true)` calls `OnboardingStorage.setCompleted(true)`, whose `clearProgress()` removed `pendingInviteToken` but kept the invite path and preview. An owner of another baby who signs in to accept an invite lost the token half-way and routed to `/home`.

## Fix

Sign-in keeps one routing table and one accept entry point. Post-auth navigation never calls accept itself.

| Layer | Change |
|-------|--------|
| `OnboardingCoordinator` | In-memory, token-bound "Accept requested before sign-in" intent: `requestAcceptAfterSignIn`, `acceptRequestedBeforeSignIn`, `takeAcceptRequestedBeforeSignIn`. Cleared by `clearPendingInvite` (accept, decline, sign-out). |
| `AppSession.signedInResumeLocation` / `redirectFor` | New row: intent set → invite landing, checked before `canAccessMainApp` so existing members are not dropped on `/home`. `_inviteResumePath(signedIn: true)` never resumes a signed-in user to the `login`/`signup` steps (cold-start loop). |
| Invite landing (follower + co-owner) | After loading the preview, if the intent is set and a user is signed in, consume it and run `runInviteLandingPrimaryAction` — the same path as tapping Accept (keeps the #374 already-member no-op and email-mismatch handling). |
| `_acceptPendingInvite` / wrong-email switch | Record the intent before routing to sign-in, including after the #406 account switch. `navigateAfterCompleteProfile` consumes it for new accounts. |
| `OnboardingStorage.clearProgress` | No longer removes the invite token; the invite handoff is cleared as a unit by `clearPendingInvite` or invite completion. |
| `navigateAfterOnboardingAuth` | Unchanged from main: `context.go(signedInResumeLocation(...))`. |
| Tests | `onboarding_auth_navigation_test.dart` (no baby / follower / owner of another baby → landing), `invite_landing_accept_after_sign_in_test.dart` (auto-accept once, no intent → no accept, #374 member no-op, intent token-bound), `app_session_redirect_test.dart`, `wrong_email_switch_account_test.dart`. |

The intent is memory-only: after a cold start the landing shows and waits for a tap, it does not loop to login.

## References

- GitHub #427, #420, #417, #406, #418
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
- `apps/mobile/lib/features/onboarding/presentation/onboarding_coordinator.dart`
- `apps/mobile/lib/features/onboarding/data/onboarding_storage.dart`
- `apps/mobile/lib/features/onboarding/presentation/utils/invite_flow_navigation.dart`
