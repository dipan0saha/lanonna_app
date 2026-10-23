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

## Review follow-ups (before merge)

- **Mobile build:** `ensureInboxFirstPage` returned the `Future<void>` of the single-flight as a `Future<InboxListWindow>` (analyzer error, mobile CI red). It now awaits the flight and returns the window.
- **Cursor:** decode rejects naive timestamps, non-object payloads and oversize tokens (all `400`). No HMAC: every query is `WHERE firebase_uid = caller`, so an edited cursor can only re-page the caller's own rows.
- **One repository query:** the offset `list_notifications_for_user` and the unused `unread_only` flag are gone; the keyset query takes `after=(created_at, id)`. Postgres test covers five rows sharing one `created_at` and another user's rows.
- **Migration 045:** `SET LOCAL lock_timeout`, and drops `idx_notifications_user_created` — a strict prefix of the new index with no other reader. Plain `CREATE INDEX` because `apply_migrations.py` runs in one transaction.
- **Unread badge:** `markRead` decrements the badge with the row (not after the PATCH), invalidates any unread-count fetch already in flight, and restores both on failure. Rows with a pending PATCH stay read in pages fetched meanwhile. Navigation from a row no longer waits for the PATCH.
- **Revalidate keeps depth:** a refreshed first page whose tail is still in the window keeps the older rows and their cursor (keyset pages only gain rows at the head). A next page whose cursor was replaced meanwhile is dropped instead of overwriting the refresh.
- **Open inbox and push:** `notifyInboxMayHaveChanged` marks the window stale; an open inbox now revalidates on that change (it only repainted before).
- **Cache scope:** the inbox is per user, not per baby, so a baby switch keeps it; every sign-out / account switch / account deletion path runs `SessionCleanup.clearLocalUserData` → `clearUnreadCount` → `clearCachedInbox`, which also drops in-flight pages.
- **Calendar:** mutations now bump a list epoch and cancel in-flight list fetches, so a fetch that started before an edit is neither cached nor joined by the reload the edit triggers.
- **Shared footer:** `AppLoadMoreButton` (`core/widgets`) replaces three hand-rolled "Load more"/spinner footers (inbox, home activity, past events); the duplicate `calendarLoadMore` string is removed in favour of `actionLoadMore`. The inbox screen caches its repository in `initState` (no `context.read` in `dispose`).

## References

- `apps/mobile/lib/features/account/presentation/notifications_inbox_screen.dart`
- `apps/mobile/lib/features/account/data/notifications_repository.dart`
- `apps/mobile/lib/features/calendar/data/calendar_repository.dart`
- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`
- `services/api/src/lanonna_api/routers/notifications.py`
- `apps/mobile/lib/core/data/baby_list_cache.dart`, `gallery_repository.dart` (caching patterns)
