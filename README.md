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

**Docs:** [docs/](docs/) · **Architecture:** [docs/engineering/platform-architecture.md](docs/engineering/platform-architecture.md) · **GCP setup:** [docs/engineering/initial-setup.md](docs/engineering/initial-setup.md) · **Local dev:** [docs/engineering/development.md](docs/engineering/development.md)

## Quick start (mobile)

```bash
cd apps/mobile && flutter pub get && flutter run
```

## Status

Monorepo scaffold in place; API and worker implementation not started.

## License

TBD
