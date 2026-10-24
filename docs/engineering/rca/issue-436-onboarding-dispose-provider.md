# RCA: Onboarding screens read Provider in dispose() (#436)

## Summary

Crashlytics (lanonna-dev) reported a fatal `Null check operator used on a null value` in `Provider._inheritedElementOf` during onboarding teardown. Most events came from `onboarding_signup_screen.dart` (`_persistEmail` in `dispose()`); a smaller set from `onboarding_first_moment_screen.dart` (`_syncDraft` in `dispose()`).

## Root cause

Both screens called `context.read<OnboardingCoordinator>()` from `dispose()`. Inherited-widget lookups require an active element tree; during `dispose()` the element is deactivated and ancestors (including `Provider`) may already be unmounted. When the whole onboarding subtree is torn down (for example after signup completes), the lookup throws. Global error handlers record the failure as fatal, so it counts against crash-free sessions even though the user flow often continues.

The signup screen already persisted the email draft on every `onChanged` and when the user tapped Back (`onBack` → `goBackFromInviteAuth` with `persist: _persistEmail`), so the `dispose()` save was redundant.

The first-moment screen already synced drafts on chip toggles, name add/remove, gender change, and photo pick, but not on every keystroke in the name field; it relied on `dispose()` for partial name input.

## Fix

| Layer | Change |
|-------|--------|
| `onboarding_signup_screen.dart` | Remove `_persistEmail()` from `dispose()`; keep `onChanged` and Back persistence. |
| `onboarding_first_moment_screen.dart` | Remove `_syncDraft()` from `dispose()`; persist the name field from its `onChanged` (user edits only), the same pattern as complete-profile. A controller listener was rejected in review: it also fires when the saved draft is restored (`controller.text = ...` runs before gender and photo are restored), which would overwrite the stored gender and photo with defaults. |
| `onboarding_prototype_widgets.dart` | `PrototypeInlineNameAdd` exposes `onChanged`. |
| `test/dispose_inherited_lookup_guard_test.dart` | CI guard over `lib/`: no `context.read/watch/select`, `X.of(context)` / `X.maybeOf(context)` (any inherited widget, including `Provider.of<T>`), `dependOnInheritedWidgetOfExactType` or `findAncestor*` inside `dispose()`, directly or through private helpers in the same file (both #436 crashes went through `_persistEmail()` / `_syncDraft()`). Comments and string literals are ignored. The test has its own positive and negative cases, and it fails on the pre-fix screens. |
| `test/onboarding_first_moment_draft_test.dart` | Restoring a saved draft keeps gender and name ideas; typing in the name field persists without leaving the screen. |

## References

- GitHub #436
- `onboarding_complete_profile_screen.dart` (persists on interaction, not in `dispose()`)
