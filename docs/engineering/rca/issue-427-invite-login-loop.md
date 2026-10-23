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
| `OnboardingStorage` / `OnboardingCoordinator` | Token-bound "Accept requested before sign-in" intent persisted beside the pending invite (`saveAcceptRequestedInviteToken`), hydrated on `hydrate()`. Cleared by `clearPendingInvite` (accept, decline, sign-out). |
| `AppSession.signedInResumeLocation` / `redirectFor` | Intent set → invite landing, checked before `canAccessMainApp` so existing members are not dropped on `/home` (including cold start at `/home`). `_inviteResumePath(signedIn: true)` never resumes a signed-in user to the `login`/`signup` steps. |
| Invite landing (follower + co-owner) | After loading the preview, if the intent is set and a user is signed in, consume it and run `runInviteLandingPrimaryAction` — the same path as tapping Accept (keeps the #374 already-member no-op and email-mismatch handling). |
| `_acceptPendingInvite` / wrong-email switch | Record the intent before routing to sign-in, including after the #406 account switch. `navigateAfterCompleteProfile` consumes it for new accounts. |
| `OnboardingStorage.clearProgress` | No longer removes the invite token; the invite handoff is cleared as a unit by `clearPendingInvite` or invite completion. |
| `navigateAfterOnboardingAuth` | Unchanged from main: `context.go(signedInResumeLocation(...))`. |
| Tests | `onboarding_auth_navigation_test.dart` (no baby / follower / owner of another baby → landing), `invite_landing_accept_after_sign_in_test.dart` (auto-accept once, no intent → no accept, #374 member no-op, intent token-bound), `app_session_redirect_test.dart`, `wrong_email_switch_account_test.dart`. |

## Cold start after “Sign in to accept” (remaining #427 case)

### Symptom

The user taps **Accept Invitation** on a follower/co-owner landing, is sent to **Log in** (“Sign in to accept”), then **kills the app** before or during sign-in. On cold start they sign in with an account that **already follows or owns a baby**. They land on that baby’s **Home**; the invite stays **pending** in the API with nothing in the app pointing to it. Accounts with **no** baby still reach the invite landing via `shouldResumeInviteFlow` + `hasInviteHandoff`.

### Root cause

PR #430 (#427 fix) added an in-memory, token-bound **accept intent** (`OnboardingCoordinator._acceptRequestedToken`) so post-auth routing could prefer the invite landing over `/home`. That intent is set when Accept routes to sign-in (`requestAcceptAfterSignIn`) and read by `signedInResumeLocation` and the landing auto-continue.

A **process kill drops the intent** while **pending invite handoff** (token, path, preview) remains in `OnboardingStorage`. After cold start:

1. **`signedInResumeLocation`** — For `canAccessMainApp == true`, the row `accept intent → invite landing` is false (intent gone), so the next row `may use main app → /home` wins. `shouldResumeInviteFlow` is never reached for routing table purposes when the user is already main-app eligible.

2. **`redirectFor`** — The `canAccessMainApp` block (keep signed-in users on Home / strip onboarding) runs **before** invite-resume logic. A cold start at `/home` with a restored session therefore **stays on Home** even though handoff data still exists.

Without a persisted intent, existing members are treated like a normal sign-in to Home; the one-shot Accept the user already tapped is lost.

### Fix (cold start)

Persist the accept intent **in the same storage layer** as the pending invite (`OnboardingStorage`), keyed to the invite token. Hydrate it with the coordinator; clear it only with `clearPendingInvite` (accept, decline, sign-out) or when the stored token no longer matches the pending invite. Keep **invite-resume / accept intent ahead of** `canAccessMainApp` in both `signedInResumeLocation` and `redirectFor`.

## References

- GitHub #427, #420, #417, #406, #418
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
- `apps/mobile/lib/features/onboarding/presentation/onboarding_coordinator.dart`
- `apps/mobile/lib/features/onboarding/data/onboarding_storage.dart`
- `apps/mobile/lib/features/onboarding/presentation/utils/invite_flow_navigation.dart`
