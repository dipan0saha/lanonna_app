# RCA: Batch invite drops invalid rows when another row is valid (#422)

## Summary

On `/invite-family` (and owner onboarding batch invite), sending a batch where one row has a valid email and another has an invalid or empty email only sends the valid row, pops the screen, and shows no error. The user believes everyone was invited.

## Root cause

`BatchInviteScreen._collectInvitesToSend` skipped rows with empty or invalid emails (`continue`) without recording them. `_validateBeforeSend` returned `null` (success) as soon as **any** row was valid, so invalid sibling rows were never surfaced. `_finish` then posted only the valid rows and `context.pop()` on success.

`batchInviteInvalidEmails` only appeared when **no** row was valid. `OnboardingInviteRow` had no per-field error display for email validation.

## Fix

Batch invite now uses the app's shared form-validation pattern instead of its own error state.

| Layer | Change |
|-------|--------|
| `OnboardingInviteRow` | The email field is an `AppTextFormField` with `validator` and `autovalidateMode` parameters, instead of a hand-set `errorText`. |
| `BatchInviteScreen` | Rows are wrapped in a `Form` (`GlobalKey<FormState>`, `_validateOnInteraction`, and an `_autovalidateMode` getter), like the other forms. `_validateRowEmail` ignores blank rows and runs `validateEmail` on every row with a name or an email. When `validate()` fails on send, nothing is sent, the fields show their errors, and `batchInviteInvalidEmails` appears. Errors clear as the user fixes them. If every row is blank, `batchInviteAddEmailToSend` appears. |
| `_collectInvitesToSend` | Runs only after validation passes. It skips only blank rows and rows that already have a membership hint. |
| Dead code | Removed `_InviteRowState.emailError`, `_validateRowsForSend`, `_formLevelSendError`, and the `batchInviteNoInvitesToSend` string. |
| Tests | `batch_invite_validation_test.dart` uses a recording repository. It checks that an invalid or missing email blocks the whole send with nothing posted, that a fixed typo clears its error, that untouched rows are ignored while every filled row is sent, and that all-blank rows ask for an email. |

## References

- GitHub #422 (DL-004)
- `apps/mobile/lib/features/invitations/presentation/batch_invite_screen.dart`
- `apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_invite_row.dart`
