# RCA: Wrong-account invite — Switch account loses invite handoff (MULTI-002)

## Summary

On the **Wrong email** screen (signed-in user opened a follower invite meant for someone else), tapping **Switch account** should sign out the owner, prefill login with the invitee address, and preserve the invite token and follower onboarding path so sign-in or sign-up resumes accept-invite flow.

Instead, login opens with an empty email, generic owner copy, and no pending invite. After sign-up the app routes to owner **Complete your profile** (Mother/Father), and `POST /v1/invitations/accept` is never retried until the user re-opens the invite link.

**Test case:** MULTI-002 (P0), pre-prod test plan PR #363, GitHub issue #369.

## Root cause

`OnboardingWrongEmailScreen` sets handoff state on `InviteFlowState`, then immediately calls `SessionCleanup.clearLocalUserData()` and `signOut()`:

1. `setLoginPrefillEmail` / `setInviteResume` (`invite_flow_state.dart`)
2. `clearLocalUserData()` → `_inviteFlowState.clear()` (`session_cleanup.dart` L44–45), which nulls prefill and resume fields
3. `clearLocalSessionForSignOut()` on `OnboardingCoordinator` → `clearPendingInvite()` (persisted token and path wiped)

`OnboardingLoginScreen` restores invite context only via `takeInviteResume()` and `takeLoginPrefillEmail()` in `didChangeDependencies` — both are empty after cleanup.

Order of operations is wrong: handoff must be applied **after** session cleanup (or cleanup must exempt account-switch handoff fields).

### Not the root cause

- Login URL query params (product intentionally avoids tokens in URLs).
- Accept 403 while wrong account is signed in (expected); the bug is losing state before the invitee can authenticate.

## Related paths

| Path | Risk if unchanged |
|------|-------------------|
| `onboarding_wrong_email_screen.dart` Switch account | Only production entry for this handoff |
| `session_cleanup.dart` `clearLocalUserData` | Correctly wipes invite state on normal sign-out; must not run before handoff is re-applied |
| `onboarding_login_screen.dart` | Consumer of `takeInviteResume` / `takeLoginPrefillEmail` |
| `onboarding_signup_screen.dart` | `takeSignupPrefillEmail` — should receive same email when user taps Sign up from login |

Other sign-out flows should continue to clear `InviteFlowState` fully.

## Fix direction

| Layer | Change |
|-------|--------|
| `onboarding_wrong_email_screen.dart` | Capture invitee email, token, and path; run `clearLocalUserData()` and `signOut()` first; then `setLoginPrefillEmail`, `setSignupPrefillEmail`, and `setInviteResume` |
| Tests | Widget test: tap Switch account → navigate to login → email field prefilled; invite resume restores token/path |

## Expected behaviour after fix

Login shows invitee email prefilled and follower invite subcopy (`isInvitePath` after resume). Sign-up from login prefills the same email. After verification, user returns to follower invite accept, not owner onboarding.

## References

- `apps/mobile/lib/features/onboarding/presentation/screens/shared/onboarding_wrong_email_screen.dart`
- `apps/mobile/lib/core/auth/session_cleanup.dart`
- `apps/mobile/lib/features/invitations/presentation/invite_flow_state.dart`
- `apps/mobile/lib/features/onboarding/presentation/screens/onboarding_login_screen.dart`
- `apps/mobile/lib/features/onboarding/presentation/onboarding_coordinator.dart`
