# RCA: API `delete_unreferenced_event_cover` race with in-flight attach (#424)

| Field | Value |
|-------|--------|
| **Issue** | [#424](https://github.com/dipan0saha/lanonna_app/issues/424) (item 1) |
| **Status** | Fixed |
| **Date** | 2026-10-24 |
| **Related** | [#416](https://github.com/dipan0saha/lanonna_app/issues/416) / `orphan-event-cover-cleanup.md` |

## Summary

When an event cover is replaced, removed, or its event is deleted, `photo_lifecycle.purge_event_cover_photo_if_unreferenced` calls `delete_unreferenced_event_cover`. Under READ COMMITTED, a single `DELETE … AND NOT EXISTS (…)` can run while another transaction is committing an `events.cover_photo_id` or `birth_announcements.photo_id` reference to the same photo. The `NOT EXISTS` subqueries do not see an uncommitted reference, so the delete can succeed and then:

- `events.cover_photo_id` (`ON DELETE SET NULL`) clears the cover on commit, or
- a concurrent attach fails with a foreign-key error if ordering differs.

Re-use must always win over orphan purge.

## Root cause

`services/api/src/lanonna_api/repositories/photos.py` implemented orphan delete as one `DELETE` guarded by `NOT EXISTS` checks with no row lock. That matches the pre-#414 worker design called out in `orphan-event-cover-cleanup.md`. The daily worker purge was fixed in #414 with `FOR UPDATE SKIP LOCKED`, recheck, then delete; the API path was not updated.

A concurrent attach holds `FOR KEY SHARE` on the referenced `photos` row for the duration of its transaction (FK check). `FOR UPDATE` on that row blocks until the attach commits or rolls back, which is the correct serialization point.

## Fix

| Layer | Change |
|-------|--------|
| `repositories/photos.py` | `delete_unreferenced_event_cover` locks the `event_cover` row with `SELECT … FOR UPDATE`, re-checks `events` / `birth_announcements` in the same transaction, then deletes only if still unreferenced (same shape as `lanonna_worker.event_cover_cleanup._purge_one`, without `SKIP LOCKED` so attach wins by waiting). |
| Tests | `test_photo_purpose_postgres.py`: two-connection Postgres test with an uncommitted attach; delete must not remove the row and must return `None`. |

## Deploy notes

API deploy only; no migration or scheduler change.

## References

- `services/api/src/lanonna_api/repositories/photos.py`
- `services/worker/src/lanonna_worker/event_cover_cleanup.py`
- `services/api/tests/integration/test_photo_purpose_postgres.py`
