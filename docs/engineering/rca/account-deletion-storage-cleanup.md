# RCA: Account deletion does not purge Google Cloud Storage

## Summary

In-app **Delete account** (FR-SET-005) tombstones `app_users`, soft-deletes sole-owned baby profiles, ends memberships, purges participation (RSVPs, votes, likes, squishes), revokes biometric credentials, and deletes the Firebase Auth user. **GCS objects were never deleted**, so photos, avatars, baby export JSON, and other display/thumbnail assets could remain indefinitely after account deletion. Google Play’s data-deletion policy requires associated user data to be removed.

## Where GCS objects are created

| Asset | Bucket | Object key pattern | Owner / scope |
|-------|--------|-------------------|---------------|
| Gallery / event-cover display image | `DISPLAY_BUCKET` | `display/{photo_id}.jpg` or `.webp` | Photo row: `baby_profile_id`, `uploader_firebase_uid` |
| Feed thumbnail | `THUMBNAILS_BUCKET` | `thumbnails/{photo_id}.jpg` | Worker after finalize on display object |
| User avatar | `DISPLAY_BUCKET` | `avatars/users/{firebase_uid}/{uuid}.jpg\|webp` | `app_users.avatar_url` stores object path |
| Baby avatar | `DISPLAY_BUCKET` | `avatars/babies/{baby_profile_id}/{uuid}.jpg\|webp` | `baby_profiles.avatar_url` |
| Baby data export | `DISPLAY_BUCKET` | `exports/{baby_profile_id}/{job_id}/export.json` | `baby_data_export_jobs.object_path` |

Upload init: `POST /v1/photos/init` → signed PUT to `display/{photo_id}.*` only. Avatars: `POST /v1/uploads/display/signed-url` under `avatars/users/{firebase_uid}/` or `avatars/babies/{baby_profile_id}/`; the API and the `049` CHECK constraints only allow a row to store its own prefix (#415).

**IAM:** Cloud Run API and worker service accounts already have `roles/storage.objectAdmin` on display and thumbnails buckets (`infra/terraform/modules/platform/iam.tf`). No new bucket role was required; cleanup runs in the **worker** via Pub/Sub (same as exports and thumbnails).

## Current delete-account flow (before fix)

1. Mobile: preview → reauth → `POST /v1/me/delete-account` `{"confirm": true}` (`current_user` only — allows retry after SQL tombstone).
2. API `delete_account`: if not tombstoned → `delete_account_rows`.
3. `delete_account_rows`: revoke pending invites; purge authored photos on shared babies; hard-delete sole-owned babies; end all memberships; `purge_participation`; **purge personal rows** and tombstone `app_users` (all profile PII cleared, `display_name = 'Deleted user'`); see [account-deletion-user-data-audit.md](./account-deletion-user-data-audit.md).
4. Firebase `delete_user` (idempotent if already gone).

**Gaps:**

- No SQL removal of **photos the user uploaded on someone else’s baby** (authored media on shared babies).
- No deletion of **baby data export** job rows or export blobs for the requester.
- No **GCS** deletes for avatars, display/thumb paths, or `exports/` prefixes.
- Sole-owned baby **photo rows remained** in SQL (baby soft-delete only); only GCS was missing for those assets. **Superseded:** [baby-hard-delete.md](./baby-hard-delete.md) — sole-owned babies are hard-deleted with paths in the cleanup job payload.
- **Comments** and other authored text on shared babies correctly remain; reads show `author_display_name` from tombstoned `app_users` (`Deleted user`).

Dev-only `infra/db/hard_delete_user.py` already documents the intended hard SQL + GCS footprint; production account delete did not mirror its media/export cleanup.

## Deletion semantics (implemented)

| Data | Sole-owned baby (deleted with account) | Shared / co-owned baby | Tombstoned `app_users` row |
|------|----------------------------------------|-------------------------|----------------------------|
| Baby profile SQL | **Hard-deleted** (see baby-hard-delete RCA) | Co-owned: ownership stays with co-owner; follower babies: membership ended only | Row kept with PII stripped |
| Gallery / cover photos on sole-owned baby | SQL rows removed with baby; **GCS** deleted async from job payload | Photos **uploaded by deleting user**: SQL row removed; **GCS** deleted async | — |
| User / baby avatars | **GCS** prefix purge (`avatars/users/{uid}/`, `avatars/babies/{id}/`) | User avatar prefix only | `avatar_url` NULL |
| Baby data export files | **GCS** `exports/{baby_id}/` + job rows for sole-owned babies | Job rows for requester deleted; paths enqueued | — |
| Comments, name suggestions, registry claims | N/A (baby hard-deleted) | **Retained**; author shows as deleted member (integrity for other members) | `display_name` placeholder only |
| RSVPs, votes, likes, squishes | Purged on delete | Purged globally for user | Already purged |

**Anonymize vs delete:** Remove media and export artifacts (user-provided binary content). Keep text contributions where removal would alter another family’s timeline; tombstone supplies anonymized display name.

## Fix architecture

1. **SQL (API, one transaction):** account delete purges the user's photos on babies they do not sole-own (one `DELETE … RETURNING`; comments, squishes, tags cascade; event covers and birth announcements are cleared by `ON DELETE SET NULL`), deletes export jobs the user requested or that belong to their sole-owned babies, **hard-deletes** sole-owned babies (paths collected first), and inserts a `storage_cleanup_jobs` row (`baby_profile_ids`, `detached_objects`, `export_object_paths`) in the same transaction as the tombstone. Owner-initiated baby delete inserts its job in the same transaction as the sole-owner check and hard delete.
2. **Pub/Sub after commit:** `enqueue_storage_cleanup(job_id)` publishes `{"type":"storage_cleanup"}` on `lanonna-async-commands` (existing topic and push subscription; no Terraform change). A failed publish is logged, not raised; a delete-account retry re-publishes an unfinished job.
3. **Worker:** `run_storage_cleanup` claims `pending` → `running`, deletes detached photo objects, export objects, every photo on the deleted babies (display + thumbnail; the thumbnail key is derived when a photo had not finished processing), and the folder prefixes `avatars/babies/{id}/` and `exports/{id}/`; account jobs also delete `avatars/users/{uid}/` (baby jobs never touch the owner's avatar). Prefixes must be complete folders (trailing `/`, no empty segment). An absent object counts as deleted, so re-runs are safe. Errors release the claim for Pub/Sub retry, or mark the job `failed` on the final attempt.
4. **Recovery sweep:** Cloud Scheduler `sweep-storage-cleanup-jobs` (every 15 min, `scripts/setup-schedulers.sh`) publishes `{"type":"sweep_storage_cleanup_jobs"}`. The worker re-runs up to 10 jobs that are `pending` for over 10 minutes (lost publish), `running` for over 30 minutes (worker died), or `failed` for over 6 hours.

**Migrations:** `042_storage_cleanup_jobs.sql`; `046_tombstoned_personal_user_data.sql` applies the same personal-data purge to accounts tombstoned before it.

Personal SQL rows are audited in [account-deletion-user-data-audit.md](./account-deletion-user-data-audit.md).

## Tombstoned rows

`app_users` rows are retained for FK integrity with `email = NULL`, `avatar_url = NULL`, `display_name = 'Deleted user'`, `deleted_at` set. No separate purge job: no PII columns remain populated beyond the non-identifying placeholder name required for comment attribution.

## Verification (dev)

1. Apply migration `042`.
2. Deploy API + worker.
3. Create test user with avatar, sole-owned baby (photos + baby avatar), and a photo uploaded on a followed baby.
4. Delete account; confirm Firebase user gone, shared photo row removed, sole-owned baby hard-deleted.
5. Inspect worker logs: `storage_cleanup_completed job_id=... kind=account_delete objects_deleted=N`.
6. Confirm GCS objects absent (`gsutil ls` on prefixes/paths).
7. Retry `POST /v1/me/delete-account` after tombstone: idempotent; republish does not error if job already completed.

## PR #351 / `data-inventory.md`

On branch `cursor/legal-pages-store-listing-c9e6`, update the data-inventory table to state that account deletion enqueues **async GCS cleanup** for avatars, photos, thumbnails, and exports, with semantics above. Main does not yet include `docs/legal/data-inventory.md`.
