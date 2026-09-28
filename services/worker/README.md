# Worker service (Cloud Run)

Pub/Sub push subscriber: generate **feed thumbnails** from `display/` objects, send **Mailjet** transactional mail, optional FCM fan-out.

## Planned layout

```
services/worker/
├── Dockerfile
├── .env.example
└── src/
    ├── pubsub/          # Push handler, message validation
    ├── jobs/            # thumb_from_display, send_invite_email (idempotent)
    └── adapters/        # GCS, Mailjet, FCM — reuse domain from API where possible
```

## Operations

- **Service name:** `worker` (Cloud Run)
- **Trigger:** Pub/Sub push (authenticated)
- **Idempotency:** key on `bucket/object/generation` for thumbnail jobs

See [docs/platform-architecture.md](../../docs/platform-architecture.md).
