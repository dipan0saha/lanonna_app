# RCA: Confirm relationship shows placeholder copy after Switch account (#406)

## Summary

Wrong-account invite → **Switch account** → sign-up → complete profile → **confirm relationship** shows “Baby’s circle” / “Family” instead of the real baby name and relationship label.

## Root cause

`OnboardingWrongEmailScreen` calls `AuthSessionService.signOut()`, which runs `SessionCleanup.clearLocalUserData()` and clears `invite_preview_json` while `InviteFlowState.setInviteResume` restores only **token + path**. Login re-applies the token but not the preview JSON, so `cachedInvitePreview` is null on confirm relationship.

## Fix

| Layer | Change |
|-------|--------|
| `InviteFlowState.setInviteResume` | Optional `previewJson` (token-keyed handoff payload, not user-scoped). |
| Wrong-email switch | Captures `invitePreviewJson` from storage before sign-out; passes it into the handoff. |
| Login (and signup when applicable) | `restoreInviteHandoff` restores token, path, and preview JSON. |
| Confirm relationship | If preview still null but token exists, `ensureInvitePreviewLoaded` refetches. |

## References

- GitHub #406, #369
- `apps/mobile/lib/features/invitations/presentation/invite_flow_state.dart`
- `apps/mobile/lib/features/onboarding/presentation/screens/shared/onboarding_wrong_email_screen.dart`
