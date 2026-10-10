# Engineering documentation

| Document | Description |
|----------|-------------|
| [platform-architecture.md](platform-architecture.md) | GCP platform architecture, costs, security, 90-day playbook |
| [initial-setup.md](initial-setup.md) | GCP/Terraform dev/prod, import, sizing, manual steps |
| [development.md](development.md) | Repository layout, theming, API surface, DB tools, local dev |
| [building-the-app.md](building-the-app.md) | Prerequisite gate before main product work |
| [pre-beta-qa.md](pre-beta-qa.md) | Manual QA: App Check, encode, cache, push, deep links, invite cold start |
| [remediation-plan.md](remediation-plan.md) | Phased plan to close codebase gaps (idempotency, avatars, layering, beta hardening) |
| [code-review-findings-2026-10.md](code-review-findings-2026-10.md) | Oct 2026 full-stack review: prioritized gaps, bugs, and doc discrepancies |
| [performance.md](performance.md) | How to measure performance; optimized patterns; prioritized improvement backlog |

Product scope: [../product/requirements.md](../product/requirements.md).

**Dev implementation snapshot (2026-10):** Cloud Run `api` + `worker` on `lanonna-dev`; SQL migrations through **`023`** (`021_worker_idempotency`, `022_user_profile_demographics`; `app_versions` in `020`, `photo_baby_tags` in `019`); gallery comment **PATCH**, photo **tags** PUT; Flutter **display encode** + **CachedSignedImage** (optional stale-URL refresh); **`resolveSelectedBaby`** for baby-scoped screens; **App Check** on client + API (`APP_CHECK_ENFORCE` defaults **false** on dev deploy — see [pre-beta-qa.md](pre-beta-qa.md)). Canonical dev API URL: `apps/mobile/flavors/dev.json` → `API_BASE_URL`.
