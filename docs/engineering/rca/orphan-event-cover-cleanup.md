# RCA: Orphan event cover photos never deleted

| Field | Value |
|-------|--------|
| **Issue** | [#414](https://github.com/dipan0saha/lanonna_app/issues/414) |
| **Status** | Fixed |
| **Date** | 2026-10-23 |

## Symptom

A cover uploaded for an event (`photos.purpose = event_cover`) but never attached to an event (user cancels form, app kill, failed save) remains in Cloud SQL and GCS. Gallery delete returns 404 (gallery-only). Replacement/delete paths in `photo_lifecycle` only run when an event **had** a cover id.

## Root cause

#315 / migration `040` defined lifecycle for covers **attached** to events (replace, remove, delete event). It did not cover **never-attached** `event_cover` rows.

## Decision

**Scheduled cleanup** (not attach-in-same-transaction): event create still uploads first, then PATCHes `cover_photo_id` on save — attaching in one transaction would require a larger calendar refactor.

Worker job `purge_stale_event_covers` (Cloud Scheduler `purge-stale-event-covers`, daily 04:00 UTC, same Pub/Sub worker topic as the other sweeps) finds `event_cover` rows older than **24 hours** that no `events.cover_photo_id` or `birth_announcements.photo_id` points at (up to 500 per run). Each one is purged in its own transaction:

1. `SELECT … FOR UPDATE SKIP LOCKED` — a cover that an attach is touching right now is skipped (attaching takes a key-share lock on the photo through the FK).
2. Re-check that nothing references it, under the lock.
3. Delete the GCS objects first, then the row. If storage fails, the row stays and the next run retries, so objects are never leaked.

One failure does not stop the run; the job raises at the end so the run is marked failed.

**Account and baby deletion** already cascade or enqueue storage cleanup for baby-scoped photos; this job only handles abandoned uploads.

## Fix

| Layer | Change |
|-------|--------|
| **Worker** | `event_cover_cleanup.py` (per-photo lock + recheck, storage first) + Pub/Sub dispatch. The API has no bulk-delete path. |
| **Scheduler** | `setup-schedulers.sh` job `purge-stale-event-covers`. |

## Tests

- `services/worker/tests/test_event_cover_cleanup.py`: continues past a failure and reports it.
- `services/worker/tests/integration/test_event_cover_cleanup_postgres.py`: purges only stale unattached covers (keeps attached, announced, fresh, gallery); GCS failure keeps the row; a cover being attached is skipped.
- `test_main_pubsub_payload.py`: dispatch.
- `test_setup_schedulers.py`: includes `purge-stale-event-covers` job.

## Follow-up

`delete_unreferenced_event_cover` (API, cover replace/remove) is a single READ COMMITTED DELETE with the same narrow attach race; worth moving to the same lock-and-recheck shape.
