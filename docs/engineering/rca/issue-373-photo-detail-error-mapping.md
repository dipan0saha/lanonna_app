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
| `event_detail_screen.dart` | Snackbar + pop on **any** error | No empty state, but an offline/5xx error throws the user out with no retry, and a later refresh 404 (event deleted) only showed a generic snackbar |

Tab screens already use `AsyncTabBody` / `reportTabLoadFailure` to keep cached content on snackbar-only failures and show blocking error + retry on first load.

## Backend note (out of scope for mobile PR)

Issue repro B hit `PoolTimeout` on Cloud SQL connection checkout (`db.py`). That is intermittent infra; the client must still surface retryable errors correctly.

## Fix

One rule for every detail screen, in one place: **a real 404 is "not found"; any other error is retryable.**

| Layer | Change |
|-------|--------|
| `core/presentation/detail_screen_load.dart` | `reportDetailLoadFailure(context, error, hasContent, onNotFound, onBlockingError)`: 404 → `onNotFound`; cached content → snackbar; nothing on screen → `onBlockingError(message)`. `onNotFound` is omitted where the repository already maps 404 to `null` (announcement). |
| `core/widgets/app_load_error_pane.dart` | `AppLoadErrorPane` (message + Try again), the single blocking-error layout, used by `AsyncTabBody` and every detail screen |
| `photo_detail_screen.dart` | Initial load and refresh go through the helper; 404 → "no longer available" + leave; other errors → error pane in the subpage scaffold (back button) |
| `event_detail_screen.dart` | Same: initial load and refresh; 404 → "Event not found" + leave; other errors → error pane with Try again instead of popping out |
| `announcement_card_screen.dart` | First-load error → error pane (subpage scaffold) instead of the empty announcement |

### Detail screen audit

| Screen | 404 | Other error, nothing cached | Other error, content shown |
|--------|-----|-----------------------------|----------------------------|
| Photo detail | not found + leave | Try again pane | snackbar |
| Event detail | not found + leave | Try again pane | snackbar |
| Announcement card | repository → `null` → empty state / owner create | Try again pane | snackbar |

Registry, Gallery, Calendar and Fun tabs use `AsyncTabBody`, which now renders the same `AppLoadErrorPane`.

## Tests

- `detail_load_failure_test.dart`: blocking vs snackbar; 404 routed to `onNotFound` only when the screen handles it.
- `photo_detail_open_test.dart`: generic error shows Try again, not "Photo not found".
- `event_detail_load_error_test.dart`: 503 shows Try again and retry loads; 404 shows "Event not found".

## References

- Issue #373
- `apps/mobile/lib/core/presentation/tab_load_failure.dart`
- `apps/mobile/lib/core/widgets/async_tab_body.dart`
- `apps/mobile/lib/features/gallery/presentation/photo_detail_screen.dart`
