# Worker service (Cloud Run)

Pub/Sub push handler: **thumbnails** from `display/` objects, **Mailjet** invite email, **notifications** inbox + FCM (including weekly digest), **baby data export**, **expire pending invitations**.

Non-2xx responses on `/pubsub/push` cause Pub/Sub to retry. Both push subscriptions dead-letter after `max_delivery_attempts` (5, mirrored by `PUBSUB_MAX_DELIVERY_ATTEMPTS`) to `lanonna-async-commands-dlq`, which is retained 7 days on the `…-dlq-pull` subscription (inspect/replay: [operations.md](../../docs/engineering/operations.md#dead-letter-queue)). Monitor `thumbnail_processing_failed` / `expire_pending_invitations_failed` logs.

**Layout:** `src/lanonna_worker/` — `main.py`, `thumbnails.py`, `notifications.py`, `invite_email.py`, `invite_cleanup.py`, `baby_data_export.py`, `idempotency.py`, `db.py`, `config.py`.

Pub/Sub handlers are **idempotent** (migration `021`+). Duplicate push deliveries return **204** without duplicate inbox rows or Mailjet sends:

- **Notifications:** `worker_delivery_log` — the fan-out/notify claim is committed in the **same transaction** as the inbox inserts, so a failed run rolls the claim back and the retry re-notifies. Photo-ready uses `dedupe_key = photo_ready:{photo_id}:{generation}` (the legacy `photo_ready_notification_log` table is no longer written).
- **Invite email:** `invitations.email_invite_token` (DB delivery secret), `email_sent_at` / `email_send_claimed_at` (claim before Mailjet, token cleared on send; claim released on failure).
- **Export jobs:** the job row (`pending` → `running` → `ready`/`failed`) is the guard — never dedupe on Pub/Sub `messageId`. Pub/Sub sends `deliveryAttempt` (subscriptions with a DLQ policy): a redelivery (`> 1`) takes over a job left `running` by a crashed/timed-out attempt; only the **final** attempt marks the job `failed`, earlier failures release it to `pending` for the retry. Stale `running` jobs (> 30 min) are also reclaimed on the next export run.

## Deploy

```bash
# From services/worker
./scripts/deploy.sh

# From repository root (required after worker deploy — not under services/worker/scripts/)
../../scripts/apply-dev-run-iam.sh
```

Before deploy, if you edited [packages/email-templates](../../packages/email-templates/), run from repo root: `bash scripts/sync-email-templates.sh check` then `bash scripts/sync-email-templates.sh apply`.

`ENVIRONMENT=dev` allows default GCP project/bucket names for local runs; non-dev startup fails if those dev defaults are still configured (see `validate_worker_settings` in `config.py`).

See [docs/engineering/development.md](../../docs/engineering/development.md) and [platform-architecture.md](../../docs/engineering/platform-architecture.md).

## Tests

```bash
pip install -r requirements.txt pytest
PYTHONPATH=src pytest -q tests
```
