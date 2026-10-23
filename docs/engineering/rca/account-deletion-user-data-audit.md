# RCA: Tombstone bypass leaves personal SQL rows

**GitHub:** [#364](https://github.com/dipan0saha/lanonna_app/issues/364)

## Summary

Account delete tombstones `app_users` (keeps the row with `deleted_at`) instead of deleting it, so authored content on co-owned babies keeps a stable FK and shows "Deleted user". Child tables declared `ON DELETE CASCADE` / `SET NULL` on `app_users` never fire on a tombstone, and the tombstone itself cleared only `email`, `avatar_url` and `display_name`. After `POST /v1/me/delete-account` the database still held the person's inbox, FCM tokens, biometric keys, banner dismissals, phone / birth date / country / postal code, last-seen time, other members' inbox rows and feed summaries that embed their old name, and invitation history addressed to their email.

## Root cause

PostgreSQL applies FK actions to `DELETE`, not to an `UPDATE` that marks a row deleted. `delete_account_rows` re-implemented only some cascades (participation, memberships, photos, export jobs) and the tombstone `UPDATE` predates migration `022` (demographics) and `030` (last seen). Inbox `title` / `body` and feed `summary` are English diagnostic copy rendered with the actor's name at write time (`lanonna_activity_copy`), so nulling an id leaves the name in the text.

## User-reference audit (every column that points at a person, migrations 001–046)

| Table / column | Kind | On account delete |
|----------------|------|-------------------|
| `app_users` email, avatar_url, phone, birth_date, country_code, postal_code, last_seen_at, biometric_unlock_enabled | profile PII | **Cleared** by `tombstone_user`; `display_name = 'Deleted user'`. Kept: `terms_accepted_at` (record of acceptance), notification preference flags (not personal), timestamps |
| `baby_profiles` (all baby-scoped rows) where the user is the only active owner | baby | **Hard-deleted** under the baby row lock; CASCADE removes every member's content on it; GCS via `storage_cleanup_jobs` |
| `baby_profiles.created_by_firebase_uid` (co-owned) | metadata | Kept |
| `baby_memberships.firebase_uid`, `relationship_label` | membership | `removed_at` set; row kept (re-invite semantics, label is the owner's description) |
| `photos.uploader_firebase_uid` on shared babies | authored media | **Deleted** (SQL + async GCS) |
| `photo_comments`, `event_comments`, `announcement_comments` `.author_firebase_uid` | authored text | Kept, shown as "Deleted user" |
| `events.created_by`, `registry_items.created_by`, `name_suggestions.suggested_by`, `birth_announcements.created_by`, `registry_purchases.purchased_by` (registry claims) | authored | Kept, shown as "Deleted user" |
| `photo_squishes`, `event_rsvps`, `votes`, `name_suggestion_likes`, `announcement_squishes` | presence | **Deleted** everywhere (`purge_participation`) |
| `activity_events.actor_firebase_uid`, `payload.target_firebase_uid` | feed | Row kept; `summary` **re-rendered** with "Deleted user" (`rerender_activity_summaries`) |
| `notifications.firebase_uid` | own inbox | **Deleted** |
| `notifications.actor_firebase_uid` / `actor_display_name` / `body` | other people's inbox rows about this person | **Deleted** (the stored body embeds the name; the content they point at is presence, a removed photo, or a comment that stays visible in place) |
| `device_tokens.firebase_uid` | FCM target | **Deleted** |
| `announcement_dismissals.firebase_uid` | banner dismissals | **Deleted** |
| `biometric_credentials.firebase_uid` (+ challenges by CASCADE) | device public keys | **Deleted** |
| `invitations.inviter_firebase_uid` | invites sent | Pending → `revoked`; history kept (invitee emails are the baby's record of who was invited). Sole-owned babies: removed by CASCADE |
| `invitations.invitee_email` = user's email | invites received | Accepted / revoked / expired rows **deleted**; pending rows kept (the inviter's open offer; they expire in 14 days) |
| `baby_data_export_jobs.requested_by_firebase_uid` | export | **Deleted** with the GCS export objects |
| `storage_cleanup_jobs.firebase_uid` | operations | Inserted; holds the uid and object paths only (no name or email) for retries and audit |

Baby-scoped notifications on a sole-owned baby also go with the baby (`notifications.baby_profile_id` CASCADE, `043`).

## Fix

1. `repositories/account_delete_user_data.py`, called by `delete_account_rows` inside its single transaction: `purge_personal_user_data` (before the tombstone; needs the email), `tombstone_user`, `rerender_activity_summaries` (after the tombstone so the live name lookup returns "Deleted user").
2. Migration `046_tombstoned_personal_user_data.sql` (`lock_timeout` 5 s, idempotent) applies the same rules to accounts tombstoned earlier. Invites they received cannot be matched for those accounts (email already cleared). Its feed sentences are a frozen copy of `activity_summary`; `test_migration_046_summary_matches_activity_copy` checks parity.
3. The dev script `scripts/delete_dev_account.sh` (was `hard_delete_user.sh`) now calls `domain.account_delete.delete_account`, so dev cleanup and the product path are one implementation.

## Verification

- `services/api/tests/integration/test_account_delete_user_data_postgres.py` (live path, 046 backfill run twice, summary parity per event type).
- Dev: delete a throwaway account with inbox rows and a device token through the API; no rows remain for its uid and its `app_users` PII columns are null.
