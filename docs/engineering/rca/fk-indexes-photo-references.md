# RCA: Missing indexes on referencing FK columns (`photos`, deletes, hot lookups)

| Field | Value |
|-------|--------|
| **Issue** | (none — owner chose no GitHub issue) |
| **Status** | Fixed |
| **Date** | 2026-10-24 |
| **Related** | [#424](https://github.com/dipan0saha/lanonna_app/issues/424) stale event-cover purge, [#315](https://github.com/dipan0saha/lanonna_app/issues/315) cover lifecycle, [baby-hard-delete.md](./baby-hard-delete.md), [account-deletion-user-data-audit.md](./account-deletion-user-data-audit.md) |

## Summary

Migration `050` added a partial index on `photos` so the nightly stale `event_cover` purge can scan candidates efficiently. The **referencing** side of the same lifecycle — `events.cover_photo_id` and `birth_announcements.photo_id` — had no btree index. Every `NOT EXISTS` check in `delete_unreferenced_event_cover` and `_stale_cover_ids`, and every `ON DELETE SET NULL` when a `photos` row is removed, therefore seq-scanned `events` and `birth_announcements`.

A full audit of migrations `001`–`050` found a small set of other FK columns with the same gap on delete-heavy or hot paths. Migration `051` adds only those indexes. Author-metadata FKs to `app_users` stay unindexed because production tombstones users instead of deleting `app_users` rows, so parent-side FK actions never run.

## Root cause

Indexes were added for **read** queries (gallery lists, inbox keyset, engagement aggregates) but not systematically for **referencing** FK columns used when the parent row is deleted or when anti-join probes run at scale.

PostgreSQL does not create indexes automatically on the referencing side of a foreign key. Without a leading-column index, `DELETE FROM photos …` triggers sequential scans on child tables, and `NOT EXISTS (SELECT 1 FROM events e WHERE e.cover_photo_id = p.id)` cannot use an index-only lookup.

## Audit (migrations 001–050)

Legend: **Add** = new index in `051`; **Covered** = existing btree/unq/PK with FK column as left prefix (non-partial, or partial documented under allowlist); **Skip** = no index needed (see rationale).

### References to `photos (id)`

| Child table.column | ON DELETE | Workload that probes it | Decision |
|--------------------|-----------|-------------------------|----------|
| `events.cover_photo_id` | SET NULL | `delete_unreferenced_event_cover`, `_stale_cover_ids` `NOT EXISTS`; gallery/cover delete FK action | **Add** partial `(cover_photo_id) WHERE cover_photo_id IS NOT NULL` — most events have no cover |
| `birth_announcements.photo_id` | SET NULL | Same `NOT EXISTS` pair; announcement photo replace; photo delete FK action | **Add** partial `(photo_id) WHERE photo_id IS NOT NULL` — many babies have no announcement photo |
| `photo_squishes.photo_id` | CASCADE | Photo delete | **Covered** — PK `(photo_id, firebase_uid)` |
| `photo_comments.photo_id` | CASCADE | Photo delete | **Covered** — `idx_photo_comments_photo (photo_id, …)` |
| `photo_baby_tags.photo_id` | CASCADE | Photo delete | **Covered** — PK `(photo_id, tagged_baby_profile_id)` |

### References to `baby_profiles (id)`

| Child table.column | ON DELETE | Workload | Decision |
|--------------------|-----------|----------|----------|
| `baby_memberships.baby_profile_id` | (default) / CASCADE after 043 | Baby hard-delete CASCADE | **Covered** — `UNIQUE (baby_profile_id, firebase_uid)` |
| `photos.baby_profile_id` | CASCADE | Baby delete; gallery lists | **Covered** — `idx_photos_baby_created`, gallery partial, etc. |
| `events.baby_profile_id` | CASCADE | Calendar lists; baby delete | **Covered** — `idx_events_baby_starts` |
| `registry_items.baby_profile_id` | CASCADE | Registry; baby delete | **Covered** — `idx_registry_items_baby*` |
| `name_suggestions.baby_profile_id` | CASCADE | Fun names; baby delete | **Covered** — `idx_name_suggestions_baby` |
| `activity_events.baby_profile_id` | CASCADE | Home feed; baby delete | **Covered** — `idx_activity_events_baby_created` |
| `invitations.baby_profile_id` | CASCADE | Invites; baby delete | **Covered** — `idx_invitations_baby_status` |
| `votes.baby_profile_id` | CASCADE | Predictions; baby delete | **Covered** — `idx_votes_baby_type` |
| `birth_announcements.baby_profile_id` | CASCADE | One row per baby (`UNIQUE`) | **Covered** — unique constraint index |
| `baby_data_export_jobs.baby_profile_id` | CASCADE | Export jobs; baby delete | **Covered** — `idx_baby_data_export_jobs_baby_created` |
| `photo_baby_tags.tagged_baby_profile_id` | CASCADE | Tag queries; baby delete | **Covered** — `idx_photo_baby_tags_tagged_baby` |
| `notifications.baby_profile_id` | CASCADE (043) | Baby hard-delete CASCADE on inbox rows | **Add** partial `(baby_profile_id) WHERE baby_profile_id IS NOT NULL` — many inbox rows are global/digest |

### References to `app_users (firebase_uid)`

Production deletes **never** `DELETE FROM app_users`; account delete tombstones the row. FK `ON DELETE CASCADE` / `SET NULL` on `app_users` therefore does not run in normal operation. Indexes below are justified by **explicit** SQL in account/baby delete and participation purge, or marked **Skip** when only the theoretical FK action would matter.

| Child table.column | Workload | Decision |
|--------------------|----------|----------|
| `photos.uploader_firebase_uid` | `purge_authored_photos_on_shared_babies` `DELETE … WHERE uploader_firebase_uid = $1` | **Add** `(uploader_firebase_uid)` |
| `baby_data_export_jobs.requested_by_firebase_uid` | `collect_and_delete_export_jobs` `DELETE … WHERE requested_by_firebase_uid = $1` | **Add** `(requested_by_firebase_uid)` |
| `invitations.inviter_firebase_uid` | `delete_account_rows` `UPDATE … WHERE inviter_firebase_uid = $1 AND status = 'pending'` | **Add** `(inviter_firebase_uid)` |
| `baby_memberships.firebase_uid` | `GET` babies for user; membership lists | **Covered** for hot reads — partial `idx_baby_memberships_user WHERE removed_at IS NULL` (allowlisted for strict FK guard; removed memberships are rare) |
| `device_tokens.firebase_uid` | Account delete purge | **Covered** — `idx_device_tokens_firebase_uid` |
| `notifications.firebase_uid` | Inbox; account delete purge | **Covered** — `idx_notifications_user_created_id` |
| `photo_squishes.firebase_uid` | `purge_participation` | **Covered** — `idx_photo_squishes_firebase_uid` |
| `announcement_squishes.firebase_uid` | `purge_participation` | **Covered** — `idx_announcement_squishes_firebase_uid` |
| `registry_purchases.purchased_by_firebase_uid` | Engagement aggregate | **Covered** — `idx_registry_purchases_purchased_by` |
| `event_rsvps.firebase_uid` | `purge_participation` `DELETE … WHERE firebase_uid = $1` | **Allowlist** — partial `idx_event_rsvps_firebase_uid_going` serves engagement; full FK index would duplicate; table moderate size |
| `votes.firebase_uid` | `purge_participation` | **Allowlist** — `UNIQUE (baby_profile_id, firebase_uid, vote_type)` does not lead with `firebase_uid`; votes per user are small |
| `name_suggestion_likes.firebase_uid` | `purge_participation` | **Covered** — `idx_name_suggestion_likes_user` |
| `storage_cleanup_jobs.firebase_uid` | Inflight job guard | **Allowlist** — partial unique on `(firebase_uid)` for pending/running `account_delete`; completed jobs retained for audit |
| `biometric_credentials.firebase_uid` | Account delete purge | **Allowlist** — partial unique `(firebase_uid, device_id) WHERE revoked_at IS NULL`; purge deletes all rows for uid in SQL |
| `announcement_dismissals.firebase_uid` | Account delete purge | **Allowlist** — PK leads with `announcement_id`; dismissals per user are tiny |
| `events.created_by_firebase_uid` | Display only | **Skip** — no delete-path scan; tombstone not parent DELETE |
| `registry_items.created_by_firebase_uid` | Display only | **Skip** |
| `name_suggestions.suggested_by_firebase_uid` | Display only | **Skip** |
| `birth_announcements.created_by_firebase_uid` | Display only | **Skip** |
| `activity_events.actor_firebase_uid` | Feed; nullable | **Skip** — rerender on tombstone, not FK cascade |
| `notifications.actor_firebase_uid` | Inbox metadata | **Skip** — account delete deletes by recipient/actor in SQL |
| `photo_comments.author_firebase_uid` | Engagement / moderation | **Allowlist** — partial `WHERE deleted_at IS NULL`; soft-deleted rows keep FK |
| `event_comments.author_firebase_uid` | Same | **Allowlist** |
| `announcement_comments.author_firebase_uid` | Same | **Allowlist** |
| `baby_profiles.created_by_firebase_uid` | Onboarding gate | **Skip** — metadata only |

### Other referenced tables (`events`, `registry_items`, `name_suggestions`, `birth_announcements`, `system_announcements`, `biometric_credentials`)

| Child table.column | Decision |
|--------------------|----------|
| `event_rsvps.event_id` | **Covered** — PK `(event_id, firebase_uid)` |
| `event_comments.event_id` | **Covered** — `idx_event_comments_event` |
| `registry_purchases.registry_item_id` | **Covered** — `UNIQUE (registry_item_id)` |
| `name_suggestion_likes.name_suggestion_id` | **Covered** — PK `(name_suggestion_id, firebase_uid)` |
| `announcement_squishes.announcement_id` | **Covered** — PK `(announcement_id, firebase_uid)` |
| `announcement_comments.announcement_id` | **Covered** — `idx_announcement_comments_announcement` |
| `announcement_dismissals.announcement_id` | **Covered** — PK `(announcement_id, firebase_uid)` |
| `biometric_sign_in_challenges.credential_id` | **Covered** — `biometric_sign_in_challenges_credential_idx` |

## Expected plan (after fix)

Stale cover candidate probe (worker / API shape) should use **Index Scan** or **Bitmap Index Scan** on `idx_events_cover_photo_id` / `idx_birth_announcements_photo_id` for each `NOT EXISTS` leg instead of seq scans on `events` / `birth_announcements`.

```sql
EXPLAIN (COSTS OFF)
SELECT p.id
FROM photos p
WHERE p.purpose = 'event_cover'
  AND p.created_at < now() - interval '24 hours'
  AND NOT EXISTS (SELECT 1 FROM events e WHERE e.cover_photo_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM birth_announcements a WHERE a.photo_id = p.id)
ORDER BY p.created_at, p.id
LIMIT 500;
```

Photo delete should use the same indexes for `ON DELETE SET NULL` child updates.

## Fix

| Layer | Change |
|-------|--------|
| `infra/db/migrations/051_fk_reference_indexes.sql` | Partial indexes on nullable photo FKs; btree indexes on account-delete probe columns (`photos.uploader`, export requester, invite inviter); partial `notifications.baby_profile_id`. `lock_timeout` 5s; `IF NOT EXISTS`. |
| `services/api/tests/integration/test_fk_index_coverage_postgres.py` | CI guard: every FK must have a non-partial leading-column btree index unless allowlisted with rationale. |

## Deploy notes

Apply migration `051` in dev (and prod on release). No API or worker code change required. Safe before or after deploy (indexes only).

## References

- `services/api/src/lanonna_api/repositories/photos.py` — `delete_unreferenced_event_cover`
- `services/worker/src/lanonna_worker/event_cover_cleanup.py` — `_stale_cover_ids`
- `services/api/src/lanonna_api/repositories/account_delete_media.py` — `purge_authored_photos_on_shared_babies`
- `infra/db/migrations/050_photos_event_cover_purge_index.sql` — purge candidate scan (complementary, not a substitute for child FK indexes)
