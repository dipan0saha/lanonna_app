# RCA: Inbox paging, reload-on-tap, and calendar duplicate event fetches

## Summary

Runtime measurements on dev (Oct 2026) confirmed two client-side perf issues called out in [perf-audit-2026-10](../perf-audit-2026-10.md) (PERF-MOB-01) and follow-up calendar instrumentation:

1. **Notifications inbox** returns only the first API page (50 rows) with no “load more,” refetches the full first page on every open, and calls `_load()` after each row tap — discarding scroll position and issuing redundant `GET /v1/me/notifications` traffic.
2. **Calendar tab** issues **duplicate** `GET …/events` calls for the same month/upcoming key when `_load()` runs more than once before the first response (e.g. overlapping tab loads), because `CalendarRepository.listEvents` had no in-flight dedupe.

## Inbox — root causes

### 1. No cursor pagination on the client

`NotificationsRepository.listInbox()` requested `/v1/me/notifications` once and took `page.items` only (`notifications_repository.dart`). The API already supported offset/`has_more`, but the UI never paginated.

### 2. No shared inbox cache (unlike gallery / baby list)

PRs #334–#336 introduced `BabyListCache`, `GalleryRepository` windows with `KeyedSingleFlight`, and tab stale-while-revalidate. The inbox screen kept local `State` only and always blocked on a full first-page fetch in `initState`.

### 3. Tap handler always refetched

`notifications_inbox_screen.dart` called `markRead` then `await _load()` on every tap. `markRead` also invoked `notifyInboxMayHaveChanged()`, which refetches the unread badge (correct) but the screen’s unconditional `_load()` forced a full list reload.

### 4. Offset pagination is a poor fit at scale

Offset pages shift when new notifications arrive while the user scrolls (gaps/duplicates). Keyset pagination on `(created_at DESC, id DESC)` matches the existing `ORDER BY` and stays stable when rows are inserted at the head.

## Calendar — root causes

### 1. Missing in-flight dedupe on `listEvents`

`GalleryRepository` wraps window extension in `KeyedSingleFlight`. `CalendarRepository.listEvents` only checked an in-memory map; two concurrent callers with an empty cache both started HTTP requests for the same `babyId` + month/upcoming key.

### 2. Intentional dual queries per tab load

The calendar tab loads **month bounds** and **`upcoming=true`** in parallel (`calendar_screen.dart`) to build Today + Upcoming sections. That is **two distinct** event list queries per load, not a bug. The fix targets duplicate fetches of the **same** query (same month or same upcoming flag), not collapsing those two product-driven lists.

## Fix direction

| Area | Layer | Change |
|------|--------|--------|
| Inbox API | `repositories/notifications.py`, router, migration `045` | Keyset `cursor` + `next_cursor`; index `(firebase_uid, created_at DESC, id DESC)` |
| Inbox mobile | `NotificationsRepository` + inbox screen | Cached window, `extendInbox`, SWR on open, optimistic `markRead`, unread badge consistency |
| Calendar mobile | `CalendarRepository` | `KeyedSingleFlight` per list key; coalesced `_load` generation on screen |
| Tests | `services/api/tests`, `apps/mobile/test` | Cursor stability; inbox paging/optimistic tap; calendar single HTTP per key |

## References

- `apps/mobile/lib/features/account/presentation/notifications_inbox_screen.dart`
- `apps/mobile/lib/features/account/data/notifications_repository.dart`
- `apps/mobile/lib/features/calendar/data/calendar_repository.dart`
- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`
- `services/api/src/lanonna_api/routers/notifications.py`
- `apps/mobile/lib/core/data/baby_list_cache.dart`, `gallery_repository.dart` (caching patterns)
