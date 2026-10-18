# RCA: Issue #68 — Calendar “Today” section missing

## Summary

Events on the current local day were sometimes absent from the Calendar list (#68 original report), and after a partial fix the **Today** section header no longer appeared on the Calendar tab (reporter follow-up, Oct 2026).

## Timeline

1. **Before Oct 2026** — Calendar tab listed only `GET …/events?upcoming=true` (`starts_at >= now` UTC). Same-day events whose start time had already passed never appeared under the list.
2. **`398181c` (Oct 12)** — Introduced `partitionCalendarListEvents`, a **Today** + **Upcoming** split (month fetch + upcoming API), tests, and separate **Today** slivers on the Calendar tab. View-all (`/calendar/upcoming`) used `CalendarTodayUpcomingList`.
3. **`d8b13f0` (#318 prototype parity, Oct 2026)** — Replaced Today/Upcoming slivers with a single **Upcoming** caps label and `CalendarGroupedEventsCard` over `_groupedUpcoming` (`[..._today, ..._upcoming]`). **Today** header removed on the tab; data for today was still merged into the card.
4. **Issue #68 follow-up** — Event at 9:24 PM listed under **UPCOMING** at 9:26 PM with no **TODAY** section (expected per FR-CAL-001).

## Root causes

### 1. UI regression (primary for “TODAY not appearing”)

`calendar_screen.dart` stopped rendering the **Today** section while still partitioning data. Requirements and copy (`messageStartTime`, FR-CAL-001) still describe **Today** on Calendar.

### 2. UTC month bounds vs local “today” (latent data bug)

`month=YYYY-MM` used UTC month boundaries (`domain/calendar.py` `_parse_month`). The client partitions “today” from that month list using **local** calendar days. Near timezone/month boundaries, an event on “today” locally could be missing from the UTC month query and therefore vanish from both **Today** and **Upcoming** (while still plausible on the grid when another fetch included it).

## Fix direction

- One shared **Today** + **Upcoming** sections widget for Calendar tab and view-all (`AppSectionCapsLabel`, grouped cards).
- Optional `utc_offset_minutes` on month list queries so the server filters the device’s local calendar month.
- Keep home teasers on `upcoming_only` (future instants only).

## References

- `apps/mobile/lib/features/calendar/domain/calendar_event_lists.dart`
- `apps/mobile/lib/features/calendar/presentation/widgets/calendar_today_upcoming_sections.dart`
- `services/api/src/lanonna_api/domain/calendar.py` (`_parse_month`, `list_calendar_events`)
- FR-CAL-001 / FR-CAL-006 in `docs/product/requirements.md`
