# RCA: Missing referencing-side FK indexes (parent deletes, account delete)

| Field | Value |
|-------|--------|
| **Issue** | (none — owner chose no GitHub issue) |
| **Status** | Fixed |
| **Date** | 2026-10-24 |
| **Related** | [#424](https://github.com/dipan0saha/lanonna_app/issues/424) stale event-cover purge, [#315](https://github.com/dipan0saha/lanonna_app/issues/315) cover lifecycle, [baby-hard-delete.md](./baby-hard-delete.md), [account-deletion-user-data-audit.md](./account-deletion-user-data-audit.md) |

## Summary

Migration `050` indexed the `photos` side of the nightly stale event-cover purge. The **referencing** side — `events.cover_photo_id` and `birth_announcements.photo_id` — had no index, so every `NOT EXISTS` probe in `delete_unreferenced_event_cover` / `_stale_cover_ids`, and the FK check on every photo delete, seq-scanned both tables.

A full audit of every FK in migrations `001`–`050` (against a live schema) found the same gap on two more hard-deleted parents (`photos → photo_comments`, `events → event_comments`), on baby hard-delete (`notifications.baby_profile_id`), and on nine `WHERE <uid column> = $1` statements in the account-delete transaction. Migration `051` adds those indexes and a CI guard keeps the rule from regressing.

## Root cause

Indexes were added for **read** queries (gallery lists, inbox keyset, engagement aggregates). Nobody owned the **referencing** side of foreign keys, and Postgres never creates those indexes automatically.

Two facts were missed:

1. **The FK check runs on every parent DELETE, whatever the ON DELETE action.** Postgres executes `SELECT 1 FROM child WHERE fk = $1` (then cascades / sets null / raises). Without an index whose leading column is the FK column, each parent delete seq-scans the child.
2. **A partial index only serves that probe when `fk = $1` implies its predicate.** That holds for `fk IS NOT NULL` on a nullable single-column FK, not for `deleted_at IS NULL` or `status = 'going'`. `idx_photo_comments_photo` and `idx_event_comments_event` are partial on `deleted_at IS NULL` (soft-deleted comments still reference the parent), so photo and event deletes seq-scanned the comment tables even though an index "on photo_id" existed.

Which parents are deleted in production:

| Parent | Deleted? | Where |
|--------|----------|-------|
| `photos` | Yes | photo delete, cover replace/delete, stale-cover purge, account delete (`purge_authored_photos_on_shared_babies`), baby cascade |
| `events` | Yes | event delete, baby cascade |
| `baby_profiles` | Yes | baby hard-delete (`043`), account delete of sole-owned babies |
| `birth_announcements`, `name_suggestions`, `registry_items`, `system_announcements`, `biometric_credentials` | Yes (cascade / admin) | all children already covered by a PK or leading-column index |
| `app_users` | **No** | account delete tombstones the row (`tombstone_user`); only dev scripts under `infra/db/` delete it |

So FKs to `app_users` need an index only where the account-delete path queries the child by uid; the parent-side FK check never runs.

## Audit and decisions

**Add** = new in `051`. **Covered** = existing non-partial index (or `IS NOT NULL` partial) with the FK as leading column. **Allowlist** = FK to `app_users` that no delete-path query filters on.

### FKs to hard-deleted parents

| Child.column → parent | ON DELETE | Decision |
|-----------------------|-----------|----------|
| `events.cover_photo_id` → photos | SET NULL | **Add** `(cover_photo_id) WHERE cover_photo_id IS NOT NULL` (also the cover `NOT EXISTS` probes) |
| `birth_announcements.photo_id` → photos | SET NULL | **Add** `(photo_id) WHERE photo_id IS NOT NULL` (same) |
| `photo_comments.photo_id` → photos | CASCADE | **Add** `(photo_id)` — existing index is partial on `deleted_at IS NULL` |
| `event_comments.event_id` → events | CASCADE | **Add** `(event_id)` — same reason |
| `notifications.baby_profile_id` → baby_profiles | CASCADE (`043`) | **Add** `(baby_profile_id) WHERE baby_profile_id IS NOT NULL` |
| `photo_squishes.photo_id`, `photo_baby_tags.photo_id`, `event_rsvps.event_id`, `announcement_squishes.announcement_id`, `name_suggestion_likes.name_suggestion_id`, `announcement_dismissals.announcement_id` | CASCADE | **Covered** — PK leads with the FK |
| `announcement_comments.announcement_id`, `registry_purchases.registry_item_id`, `biometric_sign_in_challenges.credential_id` | CASCADE | **Covered** |
| every other `*.baby_profile_id` (memberships, photos, events, registry, names, activity, invitations, votes, announcements, export jobs, photo tags) | CASCADE | **Covered** — leading-column index or unique constraint |

### Account-delete statements (`delete_account_rows`, one transaction)

| Statement | Index |
|-----------|-------|
| `UPDATE invitations … WHERE inviter_firebase_uid = $1 AND status = 'pending'` | **Add** `idx_invitations_inviter_firebase_uid` |
| `purge_authored_photos_on_shared_babies`: `photos WHERE uploader_firebase_uid = $1` | **Add** `idx_photos_uploader_firebase_uid` |
| `collect_and_delete_export_jobs`: `WHERE requested_by_firebase_uid = $1` | **Add** `idx_baby_data_export_jobs_requested_by` |
| `soft_remove_all_memberships_for_user`: `WHERE firebase_uid = $1 AND removed_at IS NULL` | Covered — partial `idx_baby_memberships_user` matches the predicate |
| `purge_participation`: `event_rsvps WHERE firebase_uid = $1` | **Add** `idx_event_rsvps_firebase_uid_status (firebase_uid, status)`; PK leads with `event_id`. It also serves the engagement count (`status = 'going'`), so the `010` partial `idx_event_rsvps_firebase_uid_going` is dropped |
| `purge_participation`: `votes WHERE firebase_uid = $1` | **Add** `idx_votes_firebase_uid`; the unique key leads with `baby_profile_id` |
| `purge_participation`: `name_suggestion_likes`, `photo_squishes`, `announcement_squishes` | Covered (`010` / existing uid indexes) |
| `purge_personal_user_data`: `notifications`, `device_tokens WHERE firebase_uid = $1` | Covered |
| `purge_personal_user_data`: `announcement_dismissals WHERE firebase_uid = $1` | **Add** `idx_announcement_dismissals_firebase_uid`; PK leads with `announcement_id` |
| `purge_personal_user_data`: `biometric_credentials WHERE firebase_uid = $1` | **Add** `idx_biometric_credentials_firebase_uid`; the unique index is partial on `revoked_at IS NULL` and the delete removes revoked keys too |
| `purge_personal_user_data`: `notifications WHERE actor_firebase_uid = $1` | **Add** `(actor_firebase_uid) WHERE actor_firebase_uid IS NOT NULL` |
| `purge_personal_user_data`: `invitations WHERE lower(invitee_email) = lower($1) AND status <> 'pending'` | **Add** expression index `(lower(invitee_email))` |
| `rerender_activity_summaries`: `activity_events WHERE actor_firebase_uid = $1 OR payload->>'target_firebase_uid' = $1` | **Add** `(actor_firebase_uid) WHERE … IS NOT NULL` and `((payload->>'target_firebase_uid')) WHERE … IS NOT NULL`, so the planner can BitmapOr both legs |

### Allowlist (FKs to `app_users` that stay unindexed)

`baby_memberships.firebase_uid` (all queries are on active memberships, partial index), the three `*_comments.author_firebase_uid` (authored content kept on account delete; reads use partial author indexes), `storage_cleanup_jobs.firebase_uid` (only the partial in-flight guard reads it), and the attribution columns `events.created_by_firebase_uid`, `registry_items.created_by_firebase_uid`, `name_suggestions.suggested_by_firebase_uid`, `birth_announcements.created_by_firebase_uid`, `baby_profiles.created_by_firebase_uid`.

If production code ever deletes `app_users` rows, every one of these needs an index; the guard test enforces that.

## Fix

| Layer | Change |
|-------|--------|
| `infra/db/migrations/051_fk_reference_indexes.sql` | 16 indexes above, drop of the superseded `idx_event_rsvps_firebase_uid_going`. One transaction, `lock_timeout` 5s, `IF [NOT] EXISTS`. |
| `services/api/tests/integration/test_fk_index_coverage_postgres.py` | CI guard on a migrated Postgres: (1) every FK has a non-partial index, or a `<fk> IS NOT NULL` partial, with the FK as leading column (expression columns and other partial predicates do not count); (2) the allowlist may only name FKs to never-deleted parents that are still uncovered (no stale entries); (3) no `services/*/src` code runs `DELETE FROM app_users`. |

## Verification

```sql
SET enable_seqscan = off;  -- dev tables are tiny
EXPLAIN (COSTS OFF)
SELECT p.id FROM photos p
WHERE p.purpose = 'event_cover' AND p.created_at < now() - interval '24 hours'
  AND NOT EXISTS (SELECT 1 FROM events e WHERE e.cover_photo_id = p.id)
  AND NOT EXISTS (SELECT 1 FROM birth_announcements a WHERE a.photo_id = p.id)
ORDER BY p.created_at, p.id LIMIT 500;
```

Expected: anti-joins on `idx_events_cover_photo_id` and `idx_birth_announcements_photo_id`; account-delete statements use the indexes in the table above.

## Deploy notes

Indexes only, no API or worker change. Safe before or after any deploy. Apply `051` in dev now and in prod with the full chain.

## References

- `services/api/src/lanonna_api/repositories/photos.py` — `delete_unreferenced_event_cover`
- `services/worker/src/lanonna_worker/event_cover_cleanup.py` — `_stale_cover_ids`
- `services/api/src/lanonna_api/repositories/account_delete.py`, `account_delete_media.py`, `account_delete_user_data.py`, `active_participants.py`
- `infra/db/migrations/050_photos_event_cover_purge_index.sql` — purge candidate scan (complementary)
