# Worker service (Cloud Run)

Pub/Sub push handler: **thumbnails** from `display/` objects, **Mailjet** invite email, **notifications** inbox + FCM (including weekly digest), **baby data export**, **expire pending invitations**.

Non-2xx responses on `/pubsub/push` cause Pub/Sub to retry with exponential backoff (`10s`–`600s` in `pubsub.tf`). Both push subscriptions dead-letter after `max_delivery_attempts` (**12**, mirrored by `PUBSUB_MAX_DELIVERY_ATTEMPTS`) to `lanonna-async-commands-dlq`, which is retained 7 days on the `…-dlq-pull` subscription (inspect/replay: [operations.md](../../docs/engineering/operations.md#dead-letter-queue)). Invite email records `email_delivery_status` / `email_last_error` on the invitation row; transient Mailjet errors return `InviteSendOutcome.RETRY` → 500 (Pub/Sub backoff is the only retry — no in-process `sleep`), permanent failures ack 204.

**Layout:** `src/lanonna_worker/` — `main.py`, `pubsub_payload.py`, `thumbnails.py`, `notifications.py`, `invite_email.py`, `invite_cleanup.py`, `baby_data_export.py` (job lifecycle), `export/` (version 2 document), `idempotency.py`, `db.py`, `config.py`.

Pub/Sub handlers are **idempotent** (migration `021`+). Duplicate push deliveries return **204** without duplicate inbox rows or Mailjet sends:

- **Notifications:** `worker_delivery_log` — the fan-out/notify claim is committed in the **same transaction** as the inbox inserts, so a failed run rolls the claim back and the retry re-notifies. Photo-ready uses `dedupe_key = photo_ready:{photo_id}:{generation}` (legacy `photo_ready_notification_log` dropped in migration `029`).
- **Invite email:** `invitations.email_invite_token` (DB delivery secret), `email_sent_at` / `email_send_claimed_at` (claim before Mailjet, token cleared on send; claim released on failure).
- **Export jobs:** the job row (`pending` → `running` → `ready`/`failed`) is the guard — never dedupe on Pub/Sub `messageId`. Pub/Sub sends `deliveryAttempt` (subscriptions with a DLQ policy): a redelivery (`> 1`) takes over a job left `running` by a crashed/timed-out attempt; only the **final** attempt marks the job `failed`, earlier failures release it to `pending` for the retry. Stale `running` jobs (> 30 min without a heartbeat) are reclaimed on the next export run; active exports refresh `started_at` while building/uploading. Failed finalize deletes orphan GCS objects when upload succeeded but the job row could not be marked `ready`. The JSON is `export_version` 2 (`export/`): display names, no member emails or Firebase UIDs, and V4 media URLs valid up to 7 days. Signing uses `lanonna-worker` (`GCS_SIGNING_SERVICE_ACCOUNT` plus self `serviceAccountTokenCreator` from `apply-run-iam.sh`).
- **Invite link:** `INVITE_DEEP_LINK_BASE` is an https origin. Mail uses `https://{host}/invite?token=…`. The token is not logged. Hosting deploy is `scripts/deploy-invite-hosting.sh`.
- **Pub/Sub push:** malformed or permanently invalid payloads are **acked (204)** with `pubsub_payload_permanent_reject` logs (`pubsub_payload.py`); transient handler failures still return **500** for retry/DLQ. Push subscription **ack deadline** and Cloud Run **request timeout** are both **300 s** (Terraform + `deploy.sh`).
- **Invite email:** user-derived fields in HTML are escaped before Mailjet send.
- **Inbox rows:** `notify_fan_out` / `notify_user` payloads carry `notification_type` and `actor_firebase_uid`; the worker snapshots `actor_display_name` from `app_users` in the same `INSERT` (unknown type → `generic`, unknown actor → `NULL`; migrations `036`/`037`).
- **Weekly digest:** unread counts for all recipients come from one grouped query; FCM tokens are still read per recipient ([open-gaps.md](../../docs/engineering/open-gaps.md) L-31).

## Deploy

```bash
# From services/worker
./scripts/deploy.sh

# From repository root (required after worker deploy — not under services/worker/scripts/)
../../scripts/apply-run-iam.sh
```

Before deploy, if you edited [packages/email-templates](../../packages/email-templates/), run from repo root: `bash scripts/sync-email-templates.sh check` then `bash scripts/sync-email-templates.sh apply`.

`ENVIRONMENT=dev` allows default GCP project/bucket names for local runs; non-dev startup fails if those dev defaults are still configured (see `validate_worker_settings` in `config.py`).

`MAILJET_FROM_EMAIL` has no placeholder default (#43). When it is unset, deploy parses `infra/env/<env>.worker.env` and gitignored `infra/env/<env>.worker.local.env` (see `dev.worker.local.env.example` on dev). Deploy refuses a missing value or `hello@lanonna.app` before Cloud Build. Quote values that contain spaces (`MAILJET_FROM_NAME="La Nonna"`). Startup uses the same sender check in every environment.

See [docs/engineering/development.md](../../docs/engineering/development.md) and [platform-architecture.md](../../docs/engineering/platform-architecture.md).

## Tests

```bash
pip install -r requirements.txt pytest
PYTHONPATH=src pytest -q tests
```
