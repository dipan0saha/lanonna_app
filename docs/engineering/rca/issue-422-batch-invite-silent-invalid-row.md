# RCA: Batch invite drops invalid rows when another row is valid (#422)

## Summary

On `/invite-family` (and owner onboarding batch invite), sending a batch where one row has a valid email and another has an invalid or empty email only sends the valid row, pops the screen, and shows no error. The user believes everyone was invited.

## Root cause

`BatchInviteScreen._collectInvitesToSend` skipped rows with empty or invalid emails (`continue`) without recording them. `_validateBeforeSend` returned `null` (success) as soon as **any** row was valid, so invalid sibling rows were never surfaced. `_finish` then posted only the valid rows and `context.pop()` on success.

`batchInviteInvalidEmails` only appeared when **no** row was valid. `OnboardingInviteRow` had no per-field error display for email validation.

## Fix

| Layer | Change |
|-------|--------|
| `_InviteRowState` | Per-row `emailError` set during send validation. |
| `OnboardingInviteRow` | Optional `emailError` shown on the email field (same pattern as onboarding form fields). |
| `BatchInviteScreen` | `_validateRowsForSend`: every non-blank row (name or email) must have a valid email before send; blank rows are ignored. Block send and `setState` field errors instead of silently dropping rows. |
| `_collectInvitesToSend` | Only called after validation passes; no silent `continue` on invalid input. |
| Tests | Widget test: valid + invalid row blocks send and shows inline email error. |

## References

- GitHub #422 (DL-004)
- `apps/mobile/lib/features/invitations/presentation/batch_invite_screen.dart`
- `apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_invite_row.dart`
