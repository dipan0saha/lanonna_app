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

## Apply (dev)

1. Install [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-auth-proxy) (or download to `/tmp/cloud-sql-proxy`).
2. `cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5432` (use another port if 5432 is busy).
3. `export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-lanonna-app-password --project=lanonna-dev)`

**Recommended:** from repo root, in a venv with `psycopg`:

```bash
cd infra/db
DB_PASSWORD="$PGPASSWORD" python apply_migrations.py
```

`apply_migrations.py` runs every `*.sql` in lexicographic order and **skips** files whose version stem is already in `schema_migrations` (DDL in files remains idempotent for manual re-run).

**Manual:** `psql -h 127.0.0.1 -U lanonna_app -d lanonna -f infra/db/migrations/00N_….sql` for each file in order.

## Clear dev test data (retest onboarding / new baby)

With the Cloud SQL proxy running and `DB_PASSWORD` set:

```bash
cd infra/db
DB_PASSWORD="$PGPASSWORD" DB_PORT=5433 python clear_dev_test_data.py \\
  --email your@email.com --reset-onboarding --verbose
```

Removes baby profiles and related rows (`photos`, `invitations`, `activity_events`, etc.) for babies linked to that user. Keeps the Firebase `app_users` row; use `--reset-onboarding` so the app runs owner onboarding again. See `clear_dev_test_data.py --help` for `--dry-run` and `--all-babies` (requires `LANONNA_DEV_CLEAR_ALL=1`).

See also [docs/engineering/initial-setup.md](../../docs/engineering/initial-setup.md) and [building-the-app.md](../../docs/engineering/building-the-app.md).
