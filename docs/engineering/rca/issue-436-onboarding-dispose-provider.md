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
| `onboarding_first_moment_screen.dart` | Remove `_syncDraft()` from `dispose()`; add a controller listener to persist name input on change (same idea as complete-profile field persistence). |
| `test/dispose_inherited_lookup_guard_test.dart` | CI guard: no `context.read` / `Provider.of` / `AppLocalizations.of(context)` / `ScaffoldMessenger.*Of(context)` inside `dispose()` bodies under `lib/`. |

## References

- GitHub #436
- `onboarding_complete_profile_screen.dart` (persists on interaction, not in `dispose()`)
