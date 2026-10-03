# Engineering documentation

| Document | Description |
|----------|-------------|
| [platform-architecture.md](platform-architecture.md) | GCP platform architecture, costs, security, 90-day playbook |
| [initial-setup.md](initial-setup.md) | GCP/Terraform dev/prod, import, sizing, manual steps |
| [development.md](development.md) | Repository layout, theming, API surface, DB tools, local dev |
| [building-the-app.md](building-the-app.md) | Prerequisite gate before main product work |
| [pre-beta-qa.md](pre-beta-qa.md) | Manual QA: App Check, encode, cache, push, deep links, invite cold start |

Product scope: [../product/requirements.md](../product/requirements.md).

**Dev implementation snapshot (2026-10):** Cloud Run `api` + `worker` on `lanonna-dev`; SQL migrations through **`016`**; Flutter **display encode** + **CachedSignedImage**; **App Check** on client + API (`APP_CHECK_ENFORCE` on deploy). Run [pre-beta-qa.md](pre-beta-qa.md) on device before wide beta.
