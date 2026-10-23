# RCA: Orphan event cover photos never deleted

| Field | Value |
|-------|--------|
| **Issue** | (no GitHub issue yet — QA pre-prod) |
| **Status** | Fixed |
| **Date** | 2026-10-23 |

## Symptom

A cover uploaded for an event (`photos.purpose = event_cover`) but never attached to an event (user cancels form, app kill, failed save) remains in Cloud SQL and GCS. Gallery delete returns 404 (gallery-only). Replacement/delete paths in `photo_lifecycle` only run when an event **had** a cover id.

## Root cause

#315 / migration `040` defined lifecycle for covers **attached** to events (replace, remove, delete event). It did not cover **never-attached** `event_cover` rows.

## Decision

**Scheduled cleanup** (not attach-in-same-transaction): event create still uploads first, then PATCHes `cover_photo_id` on save — attaching in one transaction would require a larger calendar refactor.

Worker job `purge_stale_event_covers` deletes `event_cover` rows that:

- are not referenced by `events.cover_photo_id` or `birth_announcements.photo_id`, and
- are older than **24 hours**,

then deletes GCS objects best-effort (`photo_lifecycle` / `delete_unreferenced_event_cover` pattern). Cloud Scheduler publishes daily (same Pub/Sub worker topic as other sweeps).

**Account and baby deletion** already cascade or enqueue storage cleanup for baby-scoped photos; this job only handles abandoned uploads.

## Fix

| Layer | Change |
|-------|--------|
| **API repository** | `delete_stale_unreferenced_event_covers(older_than_hours)` bulk DELETE … RETURNING paths. |
| **Worker** | `event_cover_cleanup.py` + Pub/Sub dispatch; `setup-schedulers.sh` daily job. |
| **Tests** | Unit test for SQL/worker; scheduler script expects fourth job. |

## Tests

- `test_event_cover_cleanup.py` (worker)
- `test_setup_schedulers.py`: includes `purge-stale-event-covers` job
