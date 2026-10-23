# RCA: Photo detail shows "Photo not found" for any load failure (#373)

## Summary

Opening a photo (e.g. from inbox deep link `/gallery/photo/{id}` or an FCM push) while offline or after a transient API **5xx** shows **"Photo not found"** with only Back. The real error appears briefly in a snackbar. Users cannot retry.

## Root cause

`PhotoDetailScreen._loadInitial` handles **404** explicitly (snackbar + pop to gallery). Any other failure only calls `AppSnackBar.showAlert` and clears the loading flag without recording an error state.

`build()` treats `_detail == null` after load as **missing content** and always renders `l10n.photoNotFound` (`photo_detail_screen.dart` ~L493–498). There is no branch for a recoverable load error with **Try again**.

The same anti-pattern appears on other full-screen detail flows that conflate **empty/missing** with **failed load**:

| Screen | Failure UX | Wrong empty state? |
|--------|------------|-------------------|
| `photo_detail_screen.dart` | Snackbar only | **Yes** — `photoNotFound` |
| `announcement_card_screen.dart` | Snackbar only | **Yes** — empty announcement |
| `event_detail_screen.dart` | Snackbar + pop | No misleading empty (leaves screen) |

Tab screens already use `AsyncTabBody` / `reportTabLoadFailure` to keep cached content on snackbar-only failures and show blocking error + retry on first load.

## Backend note (out of scope for mobile PR)

Issue repro B hit `PoolTimeout` on Cloud SQL connection checkout (`db.py`). That is intermittent infra; the client must still surface retryable errors correctly.

## Fix direction

| Layer | Change |
|-------|--------|
| `core/presentation/detail_screen_load.dart` | Add `reportDetailLoadFailure` (mirror `reportTabLoadFailure`) and `DetailLoadErrorPane` (shared error + Try again layout aligned with `AsyncTabBody`) |
| `photo_detail_screen.dart` | Track `_loadError`; on non-404 failure call `reportDetailLoadFailure`; render error pane instead of `photoNotFound` |
| `announcement_card_screen.dart` | Track `_loadError` on first load failure; show error pane instead of empty announcement |
| Tests | Unit test for `reportDetailLoadFailure`; widget test that photo detail shows retry message, not `photoNotFound`, on generic API error |

## References

- Issue #373
- `apps/mobile/lib/core/presentation/tab_load_failure.dart`
- `apps/mobile/lib/core/widgets/async_tab_body.dart`
- `apps/mobile/lib/features/gallery/presentation/photo_detail_screen.dart`
