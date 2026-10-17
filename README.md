# lanonna_app

**La Nonna** — greenfield Flutter client and GCP backend (Path B).

| Area | Path | Role |
|------|------|------|
| Mobile | [`apps/mobile`](apps/mobile) | Flutter app |
| API | [`services/api`](services/api) | Cloud Run HTTP API |
| Worker | [`services/worker`](services/worker) | Cloud Run Pub/Sub jobs |
| DB | [`infra/db/migrations`](infra/db/migrations) | PostgreSQL schema |
| GCP | [`infra/gcp`](infra/gcp) | Deploy & cloud config |
| Docs | [`docs`](docs) | Architecture & development |

**Docs:** [docs/](docs/) · **Architecture:** [docs/engineering/platform-architecture.md](docs/engineering/platform-architecture.md) · **Operations:** [docs/engineering/operations.md](docs/engineering/operations.md) · **Local dev:** [docs/engineering/development.md](docs/engineering/development.md)

## Quick start (mobile)

```bash
cd apps/mobile && flutter pub get && flutter run
```

## Status

Active monorepo: Flutter client, FastAPI on Cloud Run, worker for Pub/Sub jobs, PostgreSQL migrations (`001`–`037`). Local gate: `./scripts/verify-dev-prerequisites.sh`. CI: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs API (with Postgres integration tests), worker, and Flutter checks on every pull request and push to `main`. See [docs/engineering/development.md](docs/engineering/development.md).

## License

TBD
