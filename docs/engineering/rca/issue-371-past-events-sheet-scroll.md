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

## Fix

| Layer | Change |
|-------|--------|
| `core/widgets/app_modal_sheet.dart` | `AppModalSheetListBody`: the one list body for `AppModalSheet`. Scrollable `ListView` with `shrinkWrap: true` (a short list keeps the sheet compact instead of stretching to the max height; a long one scrolls once it reaches it) and zero default padding. |
| Past events, RSVP, voters sheets | Build list children through `AppModalSheetListBody` |

### Sheet audit

| Sheet | Body | Status |
|-------|------|--------|
| Past events (`calendar_past_events_sheet.dart`) | list + `AppLoadMoreButton` | fixed |
| RSVP attendees (`event_detail_screen.dart`) | list | fixed |
| Voters (`predictions_tab.dart`) | list | fixed |
| Baby switcher | `SingleChildScrollView` | already scrolls |
| Confirm dialog (`app_confirm_dialog.dart`) | `SingleChildScrollView` | already scrolls |
| Event cover photo picker (`event_form_screen.dart`) | `SingleChildScrollView` + horizontal strip | already scrolls |
| Photo caption (`photo_upload_caption_sheet.dart`) | `SingleChildScrollView` | already scrolls |
| Announce arrival, photo source | short fixed `Column` (no list) | n/a |

No other `NeverScrollableScrollPhysics` remains in a sheet body (the predictions month grid is inline in the tab, not a sheet).

## Tests

`app_modal_sheet_list_body_test.dart` opens a real `showAppModalSheet`:
- 40 rows + `AppLoadMoreButton`: the list scrolls to the footer and the button fires (the first version of this test used a bare `Column` and failed on CI).
- 2 rows: the list is exactly its content height (sheet stays compact).

## References

- Issue #371
- PR #362 (`AppLoadMoreButton`)
- `apps/mobile/lib/core/widgets/app_modal_sheet.dart`
- `apps/mobile/lib/features/calendar/presentation/widgets/calendar_past_events_sheet.dart`
