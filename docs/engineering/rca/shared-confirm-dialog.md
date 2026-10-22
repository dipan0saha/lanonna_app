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

- Add `showConfirmDialog` / `showConfirmDialogSequence` and `AppConfirmDialog` under `lib/core/widgets/`, styled with `AppTheme` tokens (`AppMetrics`, `AppColors`, `ColorScheme.error`, `AppResponsiveButtonPair`, `OutlinedButton` cancel per prototype).
- `ConfirmDialogVariant.destructive` only where rows #1–3 already used error fill; preserve green confirm for other rows.
- Default cancel string: `actionCancel` at call sites that used equivalent `Cancel` keys (visible text unchanged).
- Keep password, forgot-password, and edit-comment as dedicated dialogs.
- Widget tests on shared dialog; update flow tests that tap confirm/cancel by label.

## Test plan

- Unit/widget: destructive confirm uses error scheme; confirm → `true`; cancel → `false`; tap barrier → `false`; sequence stops on first cancel.
- Existing: `delete_baby_profile_flow_test`, `delete_account_screen_test`, and any dialog finders still pass.

## Implementation

- `lib/core/widgets/app_confirm_dialog.dart` — `showConfirmDialog`, `showConfirmDialogSequence`, `AppConfirmDialog`, `ConfirmDialogVariant`, optional `typedConfirmationPhrase`.
- Migrated inventory rows #1–3, #5–15; left form dialogs (#4, edit comment, forgot password) unchanged.
