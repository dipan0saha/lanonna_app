# Development guide

## Repository layout

```
lanonna_app/
├── apps/
│   └── mobile/              # Flutter client (Firebase Auth, API client, display encode)
├── services/
│   ├── api/                 # Cloud Run HTTP API (JWT, CRUD, signed GCS URLs)
│   └── worker/              # Cloud Run Pub/Sub worker (thumbs, email, FCM)
├── packages/
│   └── email-templates/     # Mailjet HTML/text templates (versioned)
├── infra/
│   ├── db/migrations/       # PostgreSQL schema migrations (source of truth)
│   ├── terraform/           # GCP platform (dev/prod)
│   └── gcp/                 # Runbook + console-only steps
├── docs/                    # Architecture and engineering docs
└── .github/workflows/       # CI
```

**Deploy model:** `api` and `worker` share domain logic where practical (single backend repo or shared `packages/` module) but ship as **two Cloud Run services** — see [platform-architecture.md](platform-architecture.md).

## Prerequisites

- Flutter SDK (see `apps/mobile`)
- GCP `lanonna-dev` on Blaze, `us-central1` — see [initial-setup.md](initial-setup.md)
- Before main product work: run `./scripts/verify-dev-prerequisites.sh` — [building-the-app.md](building-the-app.md)
- Docker optional (deploy uses Cloud Build)

## Mobile app

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json
```

`google-services.json` / `GoogleService-Info.plist` are local (gitignored). Dev flavor defines: `apps/mobile/flavors/dev.json`.

## API and worker

| Service | Cloud Run name | Deploy |
|--------|----------------|--------|
| API | `api` | `services/api/scripts/deploy.sh` (uses Cloud Build; no local Docker required) |
| Worker | `worker` | `services/worker/scripts/deploy.sh` |

Dev API URL: `https://api-1008830071001.us-central1.run.app`

DB password and Mailjet keys live in **Secret Manager**; never commit `.env`.

## Database

Apply migrations from `infra/db/migrations/` against Cloud SQL (tooling choice: Flyway, Alembic, golang-migrate, etc.).

## Related reading

- [Initial GCP & infrastructure setup](initial-setup.md) — Terraform, dev/prod, manual steps
- [Platform architecture](platform-architecture.md) — media flow (display + thumb), security checklist, cost assumptions
