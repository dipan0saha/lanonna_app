# Worker service (Cloud Run)

Pub/Sub push handler: **thumbnails** from `display/` objects, **Mailjet** invite email, **notifications** inbox + FCM (including weekly digest), **expire pending invitations**.

Non-2xx responses on `/pubsub/push` cause Pub/Sub to retry; monitor `thumbnail_processing_failed` / `expire_pending_invitations_failed` logs and configure a dead-letter topic in Terraform when volume grows.

**Layout:** `src/lanonna_worker/` — `main.py`, `thumbnails.py`, `notifications.py`, `invite_email.py`, `invite_cleanup.py`, `baby_data_export.py`, `idempotency.py`, `db.py`, `config.py`.

Pub/Sub handlers are **idempotent** (migration `021`): `worker_delivery_log`, `photo_ready_notification_log`, and `invitations.email_sent_at`. Duplicate push deliveries return **204** without duplicate inbox rows or Mailjet sends.

## Deploy

```bash
# From services/worker
./scripts/deploy.sh

# From repository root (required after worker deploy — not under services/worker/scripts/)
../../scripts/apply-dev-run-iam.sh
```

Before deploy, if you edited [packages/email-templates](../../packages/email-templates/), run from repo root: `bash scripts/sync-email-templates.sh apply` (CI runs `check` on every PR).

See [docs/engineering/development.md](../../docs/engineering/development.md) and [platform-architecture.md](../../docs/engineering/platform-architecture.md).

## Tests

```bash
pip install -r requirements.txt pytest
PYTHONPATH=src pytest -q tests
```
