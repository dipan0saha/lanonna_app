# Database migrations

PostgreSQL on **Cloud SQL** — single source of truth for schema.

Apply in **lexicographic order** (filename prefix):

| File | Purpose |
|------|---------|
| `001_app_users.sql` | `schema_migrations`, `app_users` |
| `002_core_domain.sql` | `baby_profiles`, `baby_memberships`, `photos` |
| `003_user_onboarding_invitations.sql` | User `display_name`, `owner_onboarding_completed_at`, baby `lifecycle_status`, `invitations` |
| `004_onboarding_first_moment.sql` | `events`, `registry_items`, `name_suggestions` (onboarding seed + calendar/registry foundation) |
| `005_user_avatar_url.sql` | `app_users.avatar_url` (OAuth / future upload URL) |
| `006_home_activity.sql` | `activity_events` (home activity stream foundation) |
| `007_gallery_calendar_social.sql` | Gallery `caption`, event fields, squish/comments/RSVP tables |
| `008_registry_fun_social.sql` | Registry purchases, votes, name likes, shipping address |
| `009_birth_announcements.sql` | Birth announcement keepsake, squish, comments |
| `010_user_engagement_indexes.sql` | Indexes for `/v1/me/account` engagement aggregates |
| `011_notifications_and_prefs.sql` | `notifications` inbox + user notification preference columns |
| `012_export_jobs_and_account_delete.sql` | `baby_data_export_jobs` + `app_users.deleted_at` |
| `013_baby_avatar_url.sql` | `baby_profiles.avatar_url` (display upload URL) |
| `014_device_tokens_and_digest.sql` | `device_tokens` (FCM) + `app_users.last_weekly_digest_at` |
| `015_system_announcements.sql` | `system_announcements` + `announcement_dismissals` (home banners) |
| `016_notification_channels.sql` | Per-channel notification toggles on `app_users` |
| `017_registry_catalog_suggestion_id.sql` | `registry_items.catalog_suggestion_id` (AI suggestion dedupe) |
| `018_events_catalog_suggestion_id.sql` | `events.catalog_suggestion_id` (calendar AI suggestion dedupe) |
| `019_photo_baby_tags.sql` | `photo_baby_tags` (FR-GAL-008 baby tags on photos) |
| `020_app_versions.sql` | `app_versions` minimum client version per platform (FR-SET-004) |
| `021_worker_idempotency.sql` | Worker delivery dedupe, photo-ready notify log, `invitations.email_sent_at` |
| `022_user_profile_demographics.sql` | `app_users` phone, birth_date, country_code, postal_code, terms_accepted_at |
| `023_registry_shipping_structured.sql` | Structured registry shipping columns on `baby_profiles` (#408) |
| `024_baby_created_by.sql` | `baby_profiles.created_by_firebase_uid` + backfill for owner-onboarding gating (#31) |
| `025_track_migration_023_registry_shipping.sql` | Record `023` in `schema_migrations` for DBs that ran 023 before tracking insert |
| `026_export_job_started_at.sql` | `baby_data_export_jobs.started_at` + stale `running` reclaim (M-11) |
| `027_invite_email_send_claim.sql` | `invitations.email_send_claimed_at` (M-12) |
| `028_invite_email_delivery_token.sql` | `invitations.email_invite_token` cleared on send (M-41) |
| `029_drop_photo_ready_notification_log.sql` | Drop unused `photo_ready_notification_log` (L-27) |
| `030_app_users_last_seen.sql` | `app_users.last_seen_at` for throttled provisioning (#36) |
| `031_membership_joined_via.sql` | `baby_memberships.joined_via` (`created` \| `invite`) and creator backfill repair (#31) |
| `032_drop_tombstoned_participation.sql` | Delete RSVPs, votes, name loves, and squishes for already-tombstoned accounts (FR-SET-005) |
| `033_drop_ended_membership_participation.sql` | Delete those same presence rows when the person is no longer a current member (FR-INV-009 / FR-INV-010) |
| `034_invitation_email_delivery_status.sql` | `email_delivery_status`, `email_last_error`, `email_send_attempts` on invitations (#62) |
| `035_app_users_biometric_unlock.sql` | `app_users.biometric_unlock_enabled` (PRD §5.3 / M-31) |
| `036_notification_type_and_actor.sql` | `notifications.notification_type` (`photo` \| `event` \| `registry` \| `fun` \| `comment` \| `squish` \| `digest` \| `generic`, CHECK constraint), `actor_firebase_uid`, `actor_display_name`; backfills legacy types from fixed API titles and deep-link routes (no body-text matching) |
| `037_notification_actor_backfill.sql` | Backfills `actor_firebase_uid` / `actor_display_name` on legacy inbox rows from structured source rows only (time-bounded, one unambiguous candidate, never the recipient); ambiguous rows stay `NULL` |
| `038_structured_notification_activity_params.sql` | `notifications.notification_kind` + `params`, `activity_events.params`: rows record what happened and its display values; the app renders the copy from ARB (title/body/summary stay as English diagnostics). Backfills legacy rows from the fixed API titles and referenced source rows only; follower registry claims become `registry_claimed`; rows that cannot be derived keep their stored text |
| `039_baby_name_nullable_gender_not_null.sql` | `baby_profiles.name` nullable (unnamed baby = `NULL`) with `CHECK (name IS NULL OR btrim(name) <> '')`; clears names stored as exactly `'Baby'` (the app's persisted default — the only locale was English and the value was sent verbatim) or blank, and strips the matching snapshotted `baby_name` params from those babies' activity / inbox rows; `gender` `NOT NULL DEFAULT 'unknown'` after backfilling `NULL` (L-36) |

## Apply (dev)

1. Install [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-auth-proxy) (or download to `/tmp/cloud-sql-proxy`).
2. `cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5432` (use another port if 5432 is busy).
3. `export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-lanonna-app-password --project=lanonna-dev)`

**Recommended:** from repo root, in a venv with `psycopg`:

```bash
cd infra/db
DB_PASSWORD="$PGPASSWORD" python apply_migrations.py
```

`apply_migrations.py` runs every `*.sql` in lexicographic order and **skips** files whose version stem is already in `schema_migrations` (DDL in files remains idempotent for manual re-run). Confirm with `./scripts/verify-dev-migrations.sh` from the repo root (39 files as of `039`).

**Manual:** `psql -h 127.0.0.1 -U lanonna_app -d lanonna -f infra/db/migrations/00N_….sql` for each file in order.

## Clear dev test data (retest onboarding / new baby)

With the Cloud SQL proxy running and `DB_PASSWORD` set:

```bash
cd infra/db
DB_PASSWORD="$PGPASSWORD" DB_PORT=5433 python clear_dev_test_data.py \\
  --email your@email.com --reset-onboarding --verbose
```

Removes baby profiles and related rows (`photos`, `invitations`, `activity_events`, etc.) for babies linked to that user. Keeps the Firebase `app_users` row; use `--reset-onboarding` so the app runs owner onboarding again. See `clear_dev_test_data.py --help` for `--dry-run` and `--all-babies` (requires `LANONNA_DEV_CLEAR_ALL=1`).

## Hard-delete user (SQL + GCS + Firebase)

For disposable QA accounts (not Maestro smoke / `lanonna.dev.qa.*` fixtures):

```bash
./scripts/hard_delete_user.sh you@example.com
```

Sole-owned baby profiles and media are removed from Cloud SQL and GCS; co-owned babies stay; Firebase Auth user is deleted. Use `--dry-run`, `--skip-gcs`, or `--skip-firebase` as needed.

See also [docs/engineering/operations.md](../../../docs/engineering/operations.md).
