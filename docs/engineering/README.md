# Engineering documentation

| Document | Description |
|----------|-------------|
| [platform-architecture.md](platform-architecture.md) | GCP platform architecture, costs, security, 90-day playbook |
| [initial-setup.md](initial-setup.md) | GCP/Terraform dev/prod, import, sizing, manual steps |
| [development.md](development.md) | Repository layout, theming, API surface, DB tools, local dev |
| [building-the-app.md](building-the-app.md) | Prerequisite gate before main product work |

Product scope: [../product/requirements.md](../product/requirements.md).

**Dev implementation snapshot (2026-09):** Cloud Run `api` + `worker` on `lanonna-dev`; SQL migrations **`001`–`008`**; Flutter shell with **home**, **gallery**, **calendar**, **registry**, and **Family Fun** (`/gamification`); owner onboarding and invite flows; API **domain** modules for gallery, calendar, registry, fun, and home; gallery upload via `POST /v1/photos/init` + worker thumbnails and `photo_shared` activity; Mailjet invite emails via worker. Not yet: App Check enforcement, FCM push, follower UI polish, home §6.2 teasers.
