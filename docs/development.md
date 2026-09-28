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

**Deploy model:** `api` and `worker` share domain logic where practical (single backend repo or shared `packages/` module) but ship as **two Cloud Run services** — see [path_b_gcp_stack.md](path_b_gcp_stack.md).

## Prerequisites

- Flutter SDK (see `apps/mobile`)
- GCP project on Blaze, `us-central1`
- Firebase project linked to GCP
- Docker (for API/worker container builds later)

## Mobile app

```bash
cd apps/mobile
flutter pub get
flutter run
```

Configure Firebase when `google-services.json` / `GoogleService-Info.plist` are added (not committed; use team secret store).

## API and worker

Scaffold only — implementation TBD. Environment variables live in **Secret Manager** in production; use `.env.example` files locally (never commit `.env`).

## Database

Apply migrations from `infra/db/migrations/` against Cloud SQL (tooling choice: Flyway, Alembic, golang-migrate, etc.).

## Related reading

- [Infrastructure (Terraform)](infra.md) — dev/prod projects, apply, import
- [Path B GCP stack](path_b_gcp_stack.md) — media flow (display + thumb), security checklist, cost assumptions
