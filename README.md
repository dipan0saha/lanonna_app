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

**Architecture:** [docs/platform-architecture.md](docs/platform-architecture.md) · **Local dev:** [docs/development.md](docs/development.md)

## Quick start (mobile)

```bash
cd apps/mobile && flutter pub get && flutter run
```

## Status

Monorepo scaffold in place; API and worker implementation not started.

## License

TBD
