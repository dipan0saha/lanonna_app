# RCA: Baby profile deletion must hard-delete SQL rows

## Summary

PR #353 (commit `7b85b72`, [account-deletion-storage-cleanup.md](./account-deletion-storage-cleanup.md)) added async GCS cleanup via `storage_cleanup_jobs` for owner-initiated `DELETE /v1/babies/{id}` and for sole-owned babies during account deletion. **Baby domain rows remained soft-deleted** (`baby_profiles.deleted_at` set, dependent photos/events/comments/RSVPs/registry/etc. kept in Postgres). The worker loaded photo object keys from `photos` by `baby_profile_id`, so GCS cleanup depended on those rows surviving until the job ran.

**Owner decision (2026-10-21):** When a baby is removed (sole-owner delete or last-owner account delete), all SQL rows scoped to that baby are **hard-deleted**. GCS paths must be captured in the cleanup job payload **before** `DELETE`, in the same transaction. Co-owned babies are unchanged unless the baby itself is deleted or account deletion removes the last sole owner.

Tombstoned `app_users` rows stay as today (out of scope).

## Inventory: tables referencing a baby

| Table / reference | FK / link | Deletion on baby hard-delete |
|-------------------|-----------|------------------------------|
| `baby_memberships` | `baby_profile_id` → `baby_profiles` | **CASCADE** (migration 043) |
| `photos` | `baby_profile_id` | **CASCADE**; paths collected pre-delete for GCS job |
| `photo_comments`, `photo_squishes`, `photo_baby_tags` (photo side) | → `photos` | **CASCADE** via photos |
| `photo_baby_tags.tagged_baby_profile_id` | → `baby_profiles` | **CASCADE** (already) |
| `events` | `baby_profile_id` | **CASCADE** |
| `event_rsvps`, `event_comments` | → `events` | **CASCADE** via events |
| `registry_items` | `baby_profile_id` | **CASCADE** |
| `registry_purchases` | → `registry_items` | **CASCADE** via items |
| `name_suggestions` | `baby_profile_id` | **CASCADE** |
| `name_suggestion_likes` | → `name_suggestions` | **CASCADE** |
| `votes` | `baby_profile_id` | **CASCADE** |
| `activity_events` | `baby_profile_id` | **CASCADE** |
| `invitations` | `baby_profile_id` | **CASCADE** (replaces revoke-only on delete) |
| `birth_announcements` | `baby_profile_id` | **CASCADE** (already) |
| `announcement_comments`, `announcement_squishes` | → announcements | **CASCADE** via announcements |
| `baby_data_export_jobs` | `baby_profile_id` | **CASCADE**; `object_path` collected pre-delete |
| `notifications` | `baby_profile_id` (nullable) | **CASCADE** (was `SET NULL`) |
| `storage_cleanup_jobs` | `baby_profile_ids UUID[]` only | **No FK** — job row survives baby delete |
| Notification payloads / `deep_link` without `baby_profile_id` | Non-FK | Orphan inbox rows possible; rare; no baby-scoped PII beyond title/body already delivered |

Shipping address fields live on `baby_profiles` and are removed with the row.

Content authored by **other users** on that baby (follower comments, RSVPs, registry claims, etc.) is deleted with the baby — the profile no longer exists.

## GCS cleanup contract (unchanged intent, stricter payload)

1. **Same transaction:** collect `display_path` / `thumb_path` for all photos on the baby(ies), `object_path` for export jobs, insert `storage_cleanup_jobs`, then `DELETE FROM baby_profiles WHERE id = ANY(...)`.
2. **Worker:** deletes objects listed in `detached_objects` and `export_object_paths`, then prefix-purges `avatars/babies/{id}/` and `exports/{id}/`. **Does not query `photos`** (rows may be gone).
3. **Account delete:** `detached_objects` still includes photos the user uploaded on shared babies; sole-owned baby photos are merged into `detached_objects` before hard-delete.

## Co-owned babies

- `DELETE /v1/babies/{id}`: refused when more than one active owner (`cannot_delete_shared_baby`).
- Account delete: sole-owned babies hard-deleted; co-owned babies keep profile; user memberships ended and participation purged per #353.

## Migrations

- **`043_baby_hard_delete.sql`:** each FK to `baby_profiles` (`activity_events`, `baby_memberships`, `events`, `invitations`, `name_suggestions`, `notifications`, `photos`, `registry_items`, `votes`) is re-added `ON DELETE CASCADE NOT VALID` and then validated, under a 5 s `lock_timeout`. A guard fails the migration if any FK to `baby_profiles` is still not CASCADE. Backfill: one `baby_profile_delete` job per soft-deleted baby (photo and export paths in the payload), then those babies are deleted. The jobs are inserted `pending`; the worker sweep (every 15 min, pending older than 10 min) runs them, so no publish is needed. Re-runnable.
- **`044_drop_baby_profiles_deleted_at.sql`:** drops the now-unused column. Apply **after** deploying the API and worker (expand/contract), since the previous revisions still filter on it.

An integration test (`test_every_row_scoped_to_a_baby_cascades_from_it`) walks the FK tree from `baby_profiles` and fails if any FK in it is neither CASCADE nor SET NULL, so a future table cannot silently block or orphan a baby delete.

## Account delete: sole-owned babies decided inside the transaction

`delete_account_rows` locks every baby the user actively owns (`FOR UPDATE`, the same row lock co-owner invite/accept/leave take) and keeps only those with one active owner, in the same transaction as the hard delete. A co-owner accepting at the same moment either commits first (the baby is kept and passes to them) or waits until the delete has finished.

## Followers of a deleted baby still get `membership_ended`

Mobile drops a baby from the session when the API answers `403 membership_ended`. Before, that came from the soft-removed membership row; with the hard delete those rows are gone, so followers would get a generic 403 and stay stuck on the deleted baby. `membership_access_ended` now also treats a missing baby as ended access.

## Verification (dev)

1. Apply migration `043`.
2. Deploy API + worker.
3. Sole-owner delete: baby row gone, follower membership gone, related rows gone, `storage_cleanup_jobs` pending with photo paths in `detached_objects`.
4. Account delete with sole-owned baby: same; shared-baby upload in `detached_objects` only.
5. Co-owned baby: delete refused; other baby’s data untouched in integration tests.

## Legal / `data-inventory.md`

`docs/legal/data-inventory.md` is not on `main` (PR #351). Wording for the open PR: state that baby deletion **removes** profile and dependent app data from Postgres, not soft-delete retention.
