# Database migrations

PostgreSQL on **Cloud SQL** — single source of truth for schema.

Suggested first tables (product TBD): `users`, `babies`, `memberships`, `invitations`, `photos`, `device_tokens`.

Apply migrations (dev):

1. Install [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-auth-proxy) (or use `/tmp/cloud-sql-proxy` from Google’s release bucket).
2. `cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5432`
3. `export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-lanonna-app-password --project=lanonna-dev)`
4. `psql -h 127.0.0.1 -U lanonna_app -d lanonna -f infra/db/migrations/001_app_users.sql`

Alternatively use `infra/db/apply_migrations.py` inside a venv with `psycopg`.
