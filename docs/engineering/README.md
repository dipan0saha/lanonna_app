# Engineering documentation

| Document | Description |
|----------|-------------|
| [platform-architecture.md](platform-architecture.md) | GCP platform architecture, costs, security, 90-day playbook |
| [initial-setup.md](initial-setup.md) | GCP/Terraform dev/prod, import, sizing, manual steps |
| [development.md](development.md) | Repository layout, theming, API surface, DB tools, local dev |
| [building-the-app.md](building-the-app.md) | Prerequisite gate before main product work |
| [pre-beta-qa.md](pre-beta-qa.md) | Manual QA: App Check, encode, cache, push, deep links, invite cold start |
| [code-review-findings-2026-10.md](code-review-findings-2026-10.md) | Oct 2026 review — **open** gaps before beta |
| [performance.md](performance.md) | How to measure performance; optimized patterns; prioritized improvement backlog |

Product scope: [../product/requirements.md](../product/requirements.md).

**Dev implementation snapshot (2026-10):** Cloud Run `api` + `worker` on `lanonna-dev`; SQL migrations through **`027`** (`024_baby_created_by`; export/invite worker claims in `026`–`027`; structured registry shipping `023`; `021_worker_idempotency`; `app_versions` in `020`); Pub/Sub **push-only** upload path + **DLQ** on push subs; Flutter **display encode** + **CachedSignedImage**; **App Check** on client + API (`APP_CHECK_ENFORCE` defaults **false** on dev — [pre-beta-qa.md](pre-beta-qa.md)). Canonical dev API URL: `apps/mobile/flavors/dev.json` → `API_BASE_URL`. Remaining beta blockers: [code-review-findings-2026-10.md](code-review-findings-2026-10.md).
