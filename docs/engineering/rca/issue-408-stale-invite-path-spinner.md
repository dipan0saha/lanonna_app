# RCA: Former follower cold-starts to infinite invite spinner (#408)

## Summary

After leaving or being removed from their **only** baby, a signed-in user with a complete profile and **no memberships** cold-starts to a blank screen with a tiny spinner. Accessibility tree is empty.

## Root cause

Persisted `onboarding_path = follower` (and sometimes a stale step) survived **after** invite onboarding finished and the membership ended. `redirectFor` evaluated `_coordinator.isInvitePath` **before** the no-baby branch and sent the user to `_inviteResumePath()` → follower invite landing.

That screen renders `InviteLandingLoading` forever when `cachedInvitePreview` is null and there is no `pendingInviteToken` (`onboarding_follower_invite_screen.dart` L93–95).

## Fix

| Layer | Change |
|-------|--------|
| `OnboardingCoordinator.shouldResumeInviteFlow` | True only when there is an active handoff: pending token, cached preview, or an in-progress invite step **before** invite onboarding completed. False when invite onboarding completed or server says no membership and no handoff. |
| `AppSession` | Invite redirect branch uses `shouldResumeInviteFlow`; otherwise fall through to no-baby / owner resume. On fresh status load, `abandonStaleInvitePath` resets path to owner when handoff is gone. |
| `AppSession.redirectFor` | A signed-in user on a follower/co-owner invite landing with no token and no preview is sent to `signedInResumeLocation` directly (nothing to land on). |
| Invite landing screens | Missing preview/token → problem state + `leaveInvitationFlow`, never infinite loading (the signed-out case, and any race before the redirect). |
| `ensureInvitePreviewLoaded` | No token → problem/leave path instead of silent `go(carousel)` for signed-in users. |

## References

- GitHub #408, #409
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
- `apps/mobile/lib/features/onboarding/presentation/screens/follower/onboarding_follower_invite_screen.dart`
