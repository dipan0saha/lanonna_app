# RCA: Offline baby switch shows previous baby's tab data (OFF-001)

## Summary

When the user switches the selected baby while offline, Registry, Gallery, Calendar, and Home can keep rendering the **previous** baby's list content under the shell header that already shows the **new** baby's name. Failed loads surface only a snackbar instead of the blocking `AsyncTabBody` error with **Try again**, so stale rows remain interactive (wrong baby id on owner actions).

**Build / case:** dev release APK, OFF-001 tab offline, GitHub issue #372.

## Root cause

Baby-scoped tabs use `TabLoadGenerationCache` and `tabLoadShouldShowSpinner` so a baby switch shows a full-tab spinner while revalidating. On **load failure**, the catch path treats "has something to show" as `_baby != null` (or equivalent), without checking that the displayed baby matches `SelectedBabyStore.selectedBabyId` and `selectionGeneration`.

`reportTabLoadFailure` (`tab_load_failure.dart`) shows a snackbar when `hasPayload` is true and only calls `onBlockingError` when false. After an offline switch, `_baby` and list fields still hold the **old** baby until a successful load replaces them, so `hasPayload` is wrongly true and stale content stays visible.

`resolveTabLoadKind` in `build()` uses the same `_baby != null` check, so the UI stays in `TabLoadKind.content` with mismatched data.

### Why the header is correct but tabs are not

The shell top bar reads the current selection from `SelectedBabyStore` / baby list cache. Tab screens keep their own `_baby` + content state until `_load()` succeeds; the failure path never clears that state when the selection has moved on.

### Related code (same flaw)

| Location | Stale `hasPayload` signal |
|----------|---------------------------|
| `registry_screen.dart` | `hadBaby = _baby != null`; `resolveTabLoadKind(..., hasPayload: _baby != null)` |
| `gallery_screen.dart` | same |
| `calendar_screen.dart` | same (catch also clears `_loadError` when `hadBaby`) |
| `home_screen.dart` | `hasPayload: _baby != null` in catch and `resolveTabLoadKind` |
| `fun_screen.dart` | same for baby shell; sub-tabs (`names_tab`, `predictions_tab`) key off passed `baby` from parent |

`calendar_upcoming_screen.dart` does not use `reportTabLoadFailure` but should use the same selection-aware payload rule if it gains baby-scoped displayed state.

Fun tab sub-tabs only misbehave if `fun_screen` keeps showing a stale `BabySummary` in `TabLoadKind.content`; fixing the parent payload check addresses that.

## Fix direction

| Layer | Change |
|-------|--------|
| `baby_context_reload.dart` | `tabDisplayedPayloadIsCurrent`: the displayed baby id equals `SelectedBabyStore.selectedBabyId` (no generation check, so the selected baby's data survives an A → B → A round trip and a failed reload keeps it); `TabLoadGenerationCache.hasCurrentTabPayload(store, displayedBabyId)` |
| Tab screens | Use `hasCurrentTabPayload` for `reportTabLoadFailure`, `resolveTabLoadKind`, and `shouldShowTabLoadSpinner`'s `hasDisplayedPayload`; on failure when not current, clear local baby + content state before blocking error |
| Tests | `baby_context_tab_payload_test.dart` (matching rule); `registry_screen_load_error_test.dart` (offline switch blocks with Try again, never shows the previous baby's items) |

## Caches

Per-baby caches live in the repositories, keyed by baby id: calendar lists (served stale on network errors), home summary, photo detail. When the newly selected baby has a cache, the load succeeds from it and the tab shows it; the blocking error appears only when nothing for that baby exists. Fun sub-tabs (`names_tab`, `predictions_tab`) reset on `baby.id` change; `calendar_upcoming_screen` shows its error state instead of old buckets. Inbox-linked detail screens load by the route's baby id, not the selection, so they are not affected.

## Expected behaviour after fix

After switching baby offline, tabs either show cached data for **that** baby, or a blocking offline/network error with **Try again** — never another baby's registry items, photos, or events under the new name.

## References

- `apps/mobile/lib/features/home/presentation/baby_context_reload.dart`
- `apps/mobile/lib/core/presentation/tab_load_failure.dart`
- `apps/mobile/lib/core/presentation/tab_load_kind.dart`
- `apps/mobile/lib/features/registry/presentation/registry_screen.dart`
- `apps/mobile/lib/features/gallery/presentation/gallery_screen.dart`
- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`
- `apps/mobile/lib/features/home/home_screen.dart`
