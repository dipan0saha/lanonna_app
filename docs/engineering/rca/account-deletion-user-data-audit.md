# RCA: Tombstone bypass leaves personal SQL rows (notifications inbox)

**GitHub:** [#364](https://github.com/dipan0saha/lanonna_app/issues/364)

## Summary

Account delete tombstones `app_users` (`deleted_at`, PII stripped) instead of `DELETE`ing the row so authored content on co-owned babies can keep a stable FK to a placeholder display name. Several child tables use `ON DELETE CASCADE` or `ON DELETE SET NULL` on `app_users`, which **never fire** on tombstone. Inbox notifications (`notifications.firebase_uid`), FCM device rows, biometric public keys, and system-banner dismissals were left behind after `POST /v1/me/delete-account`.

## Root cause

Migration `011` defined `notifications.firebase_uid … ON DELETE CASCADE`. Production delete only runs `UPDATE app_users SET deleted_at = now(), …`. PostgreSQL cascades apply to `DELETE`, not to soft delete. The same pattern affects `device_tokens` (`014`) and `biometric_credentials` (`041`). `notifications.actor_firebase_uid` uses `ON DELETE SET NULL` (`036`) but tombstone left actor ids and display names on **other users’** inbox rows.

Dev `infra/db/hard_delete_user.py` already deleted inbox and device rows because it hard-deletes the `app_users` row; production account delete did not call the equivalent steps.

## User-reference audit (every `app_users.firebase_uid` FK)

| Table / column | Role | Today (before fix) | Should do (FR-SET-005) |
|----------------|------|--------------------|-------------------------|
| `app_users` | account | Tombstone: `deleted_at`, strip email/avatar, `display_name = 'Deleted user'` | Same (FK anchor) |
| `baby_memberships.firebase_uid` | membership | `removed_at` set; row kept | Same (audit / re-invite semantics) |
| `photos.uploader_firebase_uid` | authored media | Deleted on shared babies; sole-owned baby hard-deleted | Same ([storage RCA](./account-deletion-storage-cleanup.md)) |
| `invitations.inviter_firebase_uid` | invite sender | Pending → `revoked`; historical rows kept | Same |
| `events.created_by_firebase_uid` | authored | Kept on shared babies | Same (timeline integrity) |
| `registry_items.created_by_firebase_uid` | authored | Kept | Same |
| `name_suggestions.suggested_by_firebase_uid` | authored | Kept | Same |
| `birth_announcements.created_by_firebase_uid` | authored | Kept | Same |
| `photo_comments.author_firebase_uid` | authored | Kept | Same |
| `event_comments.author_firebase_uid` | authored | Kept | Same |
| `announcement_comments.author_firebase_uid` | authored | Kept | Same |
| `registry_purchases.purchased_by_firebase_uid` | authored | Kept | Same |
| `photo_squishes`, `event_rsvps`, `votes`, `name_suggestion_likes`, `announcement_squishes` | presence | `purge_participation` deletes all | Same |
| `activity_events.actor_firebase_uid` | feed actor | Kept; reads join tombstoned `app_users` → “Deleted user” | Same (parallel to comments) |
| `notifications.firebase_uid` | **inbox recipient** | **Orphaned** | **DELETE all rows** |
| `notifications.actor_firebase_uid` / `actor_display_name` | actor on someone else’s inbox | **Stale actor id/name** | **SET NULL** (match `ON DELETE SET NULL`) |
| `device_tokens.firebase_uid` | FCM push target | **Orphaned** | **DELETE** |
| `announcement_dismissals.firebase_uid` | product preference | **Orphaned** | **DELETE** |
| `biometric_credentials.firebase_uid` | device public key | Revoked only; row kept | **DELETE** (would CASCADE challenges) |
| `baby_data_export_jobs.requested_by_firebase_uid` | export requester | Deleted in `collect_and_delete_export_jobs` | Same |
| `storage_cleanup_jobs.firebase_uid` | async GCS job audit | Row inserted | Same (operational, not user-facing inbox) |
| `baby_profiles.created_by_firebase_uid` | metadata | Kept on co-owned babies; sole-owned baby hard-deleted | Same |

Notification preference columns live on `app_users` and are cleared with the tombstone (no separate table).

Baby-scoped notifications for a sole-owned profile are removed when the baby is hard-deleted (`notifications.baby_profile_id` `ON DELETE CASCADE`, migration `043`).

## Fix

1. **API transaction:** `purge_personal_user_data` in `delete_account_rows` (after participation purge, before tombstone `UPDATE`): anonymize actor on others’ notifications, delete inbox rows, device tokens, announcement dismissals, biometric credentials.
2. **Migration `046`:** one-time cleanup for accounts already tombstoned before the API change.
3. **Tests:** Postgres integration proving zero `notifications` / `device_tokens` / dismissals / biometric rows for the deleted uid and null actor on retained inbox rows.

GCS cleanup remains async via `storage_cleanup_jobs` ([account-deletion-storage-cleanup.md](./account-deletion-storage-cleanup.md)).

## Verification

- `pytest services/api/tests/integration/test_account_delete_user_data_postgres.py`
- After deploy + migration `046` on dev: delete a user with inbox items; `SELECT COUNT(*) FROM notifications WHERE firebase_uid = '<uid>'` → `0`.
