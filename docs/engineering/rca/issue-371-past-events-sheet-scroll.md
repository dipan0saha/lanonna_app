# RCA: Past events sheet cannot scroll (#371)

## Summary

The calendar **Past events** modal loads up to 30 rows from `GET /v1/babies/{id}/events?past=true` but only ~10 rows are visible. Drag and fling gestures do nothing; the shared `AppLoadMoreButton` footer never appears, so `offset=30` is never requested.

## Root cause

`AppModalSheet` lays out its body as `Flexible(child: child)` inside a `Column(mainAxisSize: MainAxisSize.min)` (`app_modal_sheet.dart`). The flexible region receives a **bounded max height** (sheet chrome minus title and Close).

Several sheet bodies—including past events—used a `ListView` with **`shrinkWrap: true`** and **`NeverScrollableScrollPhysics()`**. That combination sizes the list to its full content height but forbids scrolling. When content exceeds the flexible max height, Flutter **clips** the overflow. The user sees a truncated list with no scrollable ancestor.

PR #362 introduced `AppLoadMoreButton` as the shared load-more footer for inbox, home activity, and past events. That change did not introduce the physics/shrinkWrap pattern (it predates #362), but it made the bug more visible because users now expect a tappable footer at the bottom of a long list.

## Affected surfaces

Any `showAppModalSheet` body that uses non-scrollable shrink-wrapped lists inside `AppModalSheet`:

| Location | Risk |
|----------|------|
| `calendar_past_events_sheet.dart` | **Confirmed** — paging + load more |
| `event_detail_screen.dart` (RSVP sheet) | Same pattern; long attendee lists clip |
| `predictions_tab.dart` (voters sheet) | Same pattern |

Sheets that already work use `SingleChildScrollView` (e.g. baby switcher) or a normal `ListView` without `NeverScrollableScrollPhysics` inside `Flexible`.

## Fix direction

| Layer | Change |
|-------|--------|
| `core/widgets/app_modal_sheet.dart` | Add `AppModalSheetListBody` — a `ListView` configured for use inside `AppModalSheet` (no shrinkWrap, default scroll physics) |
| Past events, RSVP, voters sheets | Build list children through `AppModalSheetListBody` |
| Tests | Widget test asserts scroll physics are not `NeverScrollableScrollPhysics` for the shared list body |

## References

- Issue #371
- PR #362 (`AppLoadMoreButton`)
- `apps/mobile/lib/core/widgets/app_modal_sheet.dart`
- `apps/mobile/lib/features/calendar/presentation/widgets/calendar_past_events_sheet.dart`
