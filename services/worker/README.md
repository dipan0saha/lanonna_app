# Worker service (Cloud Run)

Pub/Sub push handler: **thumbnails** from `display/` objects, **Mailjet** invite email, **notifications** inbox + FCM (including weekly digest), **expire pending invitations**.

Non-2xx responses on `/pubsub/push` cause Pub/Sub to retry; monitor `thumbnail_processing_failed` / `expire_pending_invitations_failed` logs and configure a dead-letter topic in Terraform when volume grows.

**Layout:** `src/lanonna_worker/` — `main.py`, `thumbnails.py`, `notifications.py`, `invite_email.py`.

## Deploy

```bash
./scripts/deploy.sh
./scripts/apply-dev-run-iam.sh   # from repo root, after deploy
```

See [docs/engineering/development.md](../../docs/engineering/development.md) and [platform-architecture.md](../../docs/engineering/platform-architecture.md).

## Tests

```bash
pip install -r requirements.txt pytest
PYTHONPATH=src pytest -q tests
```
