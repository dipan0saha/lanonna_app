# Development guide

## Repository layout

```
lanonna_app/
├── apps/
│   └── mobile/              # Flutter client (Firebase Auth, API client, display encode)
├── services/
│   ├── api/                 # Cloud Run HTTP API (JWT, CRUD, signed GCS URLs)
│   └── worker/              # Cloud Run Pub/Sub worker (thumbs, email, FCM)
├── scripts/                 # verify-dev-prerequisites.sh, infra smoke, Run IAM
├── packages/
│   └── email-templates/     # Mailjet HTML/text templates (versioned)
├── infra/
│   ├── db/migrations/       # PostgreSQL schema migrations (source of truth)
│   ├── terraform/           # GCP platform (dev/prod)
│   └── gcp/                 # Resource inventory (SETUP.md)
├── docs/                    # product/ + engineering/ documentation
└── .github/workflows/       # CI (Flutter + Python compile)
```

**Deploy model:** `api` and `worker` ship as **two Cloud Run services** — see [platform-architecture.md](platform-architecture.md).

**Before main product work:** [building-the-app.md](building-the-app.md) and `./scripts/verify-dev-prerequisites.sh`.

## Prerequisites

- Flutter SDK (see `apps/mobile`)
- GCP `lanonna-dev` on Blaze, `us-central1` — [initial-setup.md](initial-setup.md)
- Docker optional (deploy uses Cloud Build)

## Mobile app

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json
```

`google-services.json` / `GoogleService-Info.plist` are local (gitignored). Dev flavor: `apps/mobile/flavors/dev.json`. iOS: minimum **15.0**, run `cd ios && pod install` once.

## API and worker

| Service | Cloud Run name | Deploy |
|--------|----------------|--------|
| API | `api` | `services/api/scripts/deploy.sh` |
| Worker | `worker` | `services/worker/scripts/deploy.sh` then `./scripts/apply-dev-run-iam.sh` |

Dev API URL: `https://api-1008830071001.us-central1.run.app`

| Method | Path | Auth |
|--------|------|------|
| GET | `/health` | Public |
| GET | `/v1/me`, `/v1/profile` | Firebase Bearer JWT |
| POST | `/v1/uploads/display/signed-url` | Firebase Bearer JWT |

Local API env: `services/api/.env.example`. DB password and Mailjet keys live in **Secret Manager**.

## Database

Apply SQL files in order from `infra/db/migrations/` (see [migrations/README.md](../infra/db/migrations/README.md)). Cloud SQL via Auth Proxy + `psql`, or `infra/db/apply_migrations.py` in a venv with `psycopg`.

## Related reading

- [building-the-app.md](building-the-app.md) — prerequisite gate
- [initial-setup.md](initial-setup.md) — Terraform, deploy, secrets
- [platform-architecture.md](platform-architecture.md) — media flow, costs, playbook
