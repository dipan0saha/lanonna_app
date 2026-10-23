# RCA: Confirm relationship shows placeholder copy after Switch account (#406)

## Summary

Wrong-account invite → **Switch account** → sign-up → complete profile → **confirm relationship** shows “Baby’s circle” / “Family” instead of the real baby name and relationship label.

## Root cause

`OnboardingWrongEmailScreen` calls `AuthSessionService.signOut()`, which runs `SessionCleanup.clearLocalUserData()` and clears `invite_preview_json` while `InviteFlowState.setInviteResume` restores only **token + path**. Login re-applies the token but not the preview JSON, so `cachedInvitePreview` is null on confirm relationship.

## Fix

| Layer | Change |
|-------|--------|
| `InviteFlowState.setInviteResume` | Optional typed `InvitationPreview` (token-keyed invite data, not user-scoped), held in memory only. |
| Wrong-email switch | Reads `cachedInvitePreview` before sign-out and passes it into the handoff. |
| Login | Takes the handoff on mount (so it lives in memory only for the navigation) and calls `OnboardingCoordinator.restoreInviteHandoff`, which restores token and path and re-stores the preview through the same field allowlist as `bindInviteFromPreview`. Sign-up from login needs nothing more: the handoff is already back in the coordinator. |

## Security review (PR #405)

- **What is carried:** invite token, onboarding path, and the preview fields the onboarding screens show (status, baby name, inviter display name, relationship label, role, baby id, lifecycle and dates). The persisted preview never contains the **invitee email**: `_previewToJson` is an allowlist, and the handoff goes through it instead of copying a raw JSON string from storage. The invitee email the login prefill needs is a separate one-shot value (`takeLoginPrefillEmail`).
- **When it is cleared:** `takeInviteResume` clears it on read; `InviteFlowState.clear()` runs on sign-out and account switch (`SessionCleanup`); `leaveInvitationFlow` now clears `InviteFlowState` as well as the stored token and preview, so "Leave this invitation" ends every handoff. A completed invite clears the stored token and preview as before.
- **Tests:** `wrong_email_switch_account_test.dart` (handoff consumed, no invitee email on disk; leave clears token, preview, mismatch and resume) and `invite_flow_state_test.dart`.

## References

- GitHub #406, #369
- `apps/mobile/lib/features/invitations/presentation/invite_flow_state.dart`
- `apps/mobile/lib/features/onboarding/presentation/screens/shared/onboarding_wrong_email_screen.dart`
