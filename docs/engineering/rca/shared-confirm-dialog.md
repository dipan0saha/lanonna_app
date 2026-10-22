# RCA: Shared confirmation dialog (mobile)

## Summary

Roughly a dozen destructive and affirmative confirmation flows in `apps/mobile` each inline an `AlertDialog` with hand-built `TextButton` / `FilledButton` actions. Cancel copy is split across three l10n keys with identical English text (`Cancel`). Destructive primary actions sometimes use `AppColors.error` on the confirm button (delete baby, delete account) and sometimes the default green `FilledButton` (delete photo, remove follower, leave baby, etc.). There is no shared layout matching the prototype’s side-by-side outline cancel + filled confirm row (`docs/prototype/nonna_combined_prototype.html`, `#confirmOverlay`).

## Inventory

| # | File | Trigger | Title (l10n key) | Message / body | Cancel label (key) | Confirm label (key) | Destructive confirm styling | Return / dismiss | Post-confirm behavior |
|---|------|---------|------------------|----------------|--------------------|---------------------|------------------------------|------------------|------------------------|
| 1 | `delete_baby_profile_flow.dart` | `deleteBabyProfileWithConfirmation` (edit baby / switcher) | `deleteBabyProfileConfirmTitle` | `deleteBabyProfileConfirmBody(name)` | `authPasswordResetCancel` | `deleteBabyProfileConfirmAction` | Yes (`AppColors.error`) | `bool`; dismiss → false | API delete, snackbar, refresh baby context, `go('/home')` |
| 2 | `delete_baby_profile_flow.dart` | Step 2 after step 1 | `deleteBabyProfileFinalTitle(name)` | `deleteBabyProfileFinalBody` | `authPasswordResetCancel` | `deleteBabyProfileConfirmAction` | Yes | `bool` | Same as #1 |
| 3 | `delete_account_screen.dart` | `_confirmDelete` before reauth | `deleteAccountConfirmTitle` | Dynamic: `deleteAccountConfirmBody` + optional sole-owned list | `authPasswordResetCancel` | `deleteAccountConfirmAction` | Yes | `bool` | Reauth (password or Google), then delete API + sign out |
| 4 | `delete_account_screen.dart` | `_askPassword` (password reauth) | `deleteAccountReauthPasswordTitle` | Field + `deleteAccountReauthPasswordBody` | `authPasswordResetCancel` | `deleteAccountReauthPasswordAction` | No (default filled) | `String?`; cancel → null | **Not migrated** — form dialog, not a simple confirm |
| 5 | `followers_screen.dart` | Remove follower | `memberRemoveConfirmTitle` | `memberRemoveConfirmBody(name)` | `authPasswordResetCancel` | `memberRemoveAction` | No | `bool` | `runMutation` remove member, refresh list |
| 6 | `baby_switcher_sheet.dart` | Leave baby (non–sole-owner) | `memberLeaveConfirmTitle` | `memberLeaveConfirmBody` | `authPasswordResetCancel` | `memberLeaveAction` | No | `bool` | `runMutation` leave, refresh, close sheet, `go('/home')` |
| 7 | `shell_top_bar.dart` | Invite family without owner baby | `shellInviteRequiresOwnerBabyTitle` | `shellInviteRequiresOwnerBabyMessage` | `authPasswordResetCancel` | `actionAddBaby` | No (affirmative CTA) | `void` (no result) | Confirm pushes `/baby/create` |
| 8 | `registry_screen.dart` | Owner marks registry item purchased | `registryMarkPurchasedTitle` | `messageItem` | `actionCancel` | `registryMarkPurchased` | No | `bool` | `runMutation` claim purchase |
| 9 | `registry_shipping_address_screen.dart` | Clear shipping address | `shippingRemoveTitle` | `messageFollowersLonger` | `actionCancel` | `actionRemove` | No | `bool` | API clear address, `pop(true)` |
| 10 | `photo_detail_screen.dart` | Owner deletes photo | `photoDeleteConfirmTitle` | `messageRemoves` | `actionCancel` | `actionDelete` | No | `bool` | API delete, notify gallery, `pop` |
| 11 | `comment_actions.dart` | `confirmDeleteComment` | `commentDeleteTitle` | *(none)* | `commentCancel` | `commentDeleteAction` | No | `bool` | Caller runs delete API |
| 12 | `event_detail_screen.dart` | Owner deletes event | `eventDeleteConfirmTitle` | `eventDeleteConfirmBody` | `actionCancel` | `actionDelete` | No | `bool` | API delete, `popOrGo` calendar |
| 13 | `home_screen.dart` | After mark born, no announcement | `homeCreateAnnouncementTitle` | `actionShareKeepsakeCardPhoto` | `actionLater` | `actionCreate` | No | `bool` | Optional push announcement create |
| 14 | `names_tab.dart` | Delete name suggestion | `funRemoveNameTitle` | `funRemoveNameBody(name)` | `actionCancel` | `actionRemove` | No | `bool` | `runMutation` delete suggestion |
| 15 | `predictions_tab.dart` | Save/update birthdate guess | `funBirthdateConfirmSaveTitle` / `funBirthdateConfirmUpdateTitle` | Matching body with date | `actionCancel` | `funBirthdateConfirmAction` | No | `bool` | Submit guess API |

### Related dialogs (out of scope for shared confirm)

| File | Purpose | Reason excluded |
|------|---------|-----------------|
| `comment_actions.dart` `showEditCommentDialog` | Edit comment text field | Form / input dialog |
| `forgot_password_dialog.dart` | Reset password email | Form / validation |
| `delete_account_screen.dart` `_askPassword` | Reauth password | Form + returns `String?` |

### Not present in codebase

- **Sign out confirmation** — `account_screen.dart` calls `AuthRepository.signOut()` directly with no dialog.
- **Typed phrase confirmation** (e.g. type baby name to delete) — not used; delete baby uses two standard confirms only.

## Inconsistencies

1. **Cancel l10n key**: `authPasswordResetCancel` vs `actionCancel` vs `commentCancel` (all English `Cancel`); home announcement uses `actionLater` (`Later`) by design.
2. **Confirm button color**: Only delete baby (#1–2) and delete account (#3) use error-filled confirm; other deletes/removes use primary-filled.
3. **Action layout**: All use stock `AlertDialog.actions` (end-aligned); prototype uses equal-width outline + filled row.
4. **Cancel control**: Plain `TextButton` vs `AppCancelTextButton` styling elsewhere — dialogs do not use `AppCancelTextButton`.
5. **Barrier dismiss**: No call site sets `barrierDismissible: false`; default dismiss yields `null` → treated as not confirmed.

## Decision

- One shared confirm: `showConfirmDialog` / `showConfirmDialogSequence` + `AppConfirmDialog` in `lib/core/widgets/app_confirm_dialog.dart`.
- **Presentation matches the prototype `#confirmOverlay`:** a modal **bottom sheet** (not a centered `AlertDialog`) built on the shared `presentAppModalSheet` / `AppModalSheet` chrome — handle, title, muted message, then an equal-width **outline Cancel + filled confirm** row (`AppResponsiveButtonPair`). The message scrolls, so long bodies (delete account's sole-owned profile list) never push the actions off-screen. The pair sits side by side when both labels fit on one line at half width, and stacks otherwise (e.g. "Mark as purchased" on a 411dp phone) so a label never wraps inside a squeezed button.
- **Styling only via theme tokens:** Cancel is a themed `OutlinedButton`; confirm is a themed `ElevatedButton` (the app's primary CTA — same size, padding and shape as the outlined half). Destructive confirm layers `AppButtonStyles.primaryDestructive` (`AppColors.error` fill).
- **Destructive styling applies to every irreversible delete/removal** (app-wide consistency): rows #1–3, #5 remove follower, #6 leave baby, #9 remove shipping address, #10 delete photo, #11 delete comment, #12 delete event, #14 remove name. Affirmative confirms stay standard (sage): #7 add baby, #8 mark purchased, #13 create announcement, #15 save birthdate guess.
- **Copy:** every title, message and confirm label is unchanged. Cancel uses `actionCancel` everywhere (English `Cancel`, previously split across `authPasswordResetCancel` / `commentCancel` / `actionCancel`); home announcement keeps `Later` by design.
- Return contract unchanged: `true` only on confirm; Cancel, barrier tap and swipe-down return `false`. Sheets use the root navigator, as `showDialog` did.
- Password reauth, forgot-password and edit-comment stay dedicated form dialogs.

## Test plan

- Unit/widget: destructive confirm uses error scheme; confirm → `true`; cancel → `false`; tap barrier → `false`; sequence stops on first cancel.
- Existing: `delete_baby_profile_flow_test`, `delete_account_screen_test`, and any dialog finders still pass.

## Implementation

- `lib/core/widgets/app_confirm_dialog.dart` — `showConfirmDialog`, `showConfirmDialogSequence`, `AppConfirmDialog`, `ConfirmDialogVariant`, `ConfirmDialogStep`.
- `lib/core/theme/app_button_styles.dart` — `primaryDestructive`.
- Migrated inventory rows #1–3, #5–15; left form dialogs (#4, edit comment, forgot password) unchanged.

## Follow-ups (not in this change)

- Registry item delete (trash icon) and pending-invite **Revoke** act immediately with no confirm. Adding a confirm there is a behaviour change, so it is left for a separate decision.
