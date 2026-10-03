# Product documentation

| Document | Description |
|----------|-------------|
| [requirements.md](requirements.md) | La Nonna product requirements (PRD): features, roles, IA, FR/NFR IDs, and acceptance traceability |

## How this fits the repo

- **What to build (product):** [requirements.md](requirements.md)
- **How to run the platform:** [platform-architecture.md](../engineering/platform-architecture.md)
- **When engineering is unblocked:** [building-the-app.md](../engineering/building-the-app.md)
- **Day-to-day dev:** [development.md](../engineering/development.md)

**Status:** Requirements v1 (draft) — Path B GCP (Firebase Auth, Cloud Run API/worker, Cloud SQL, GCS, Pub/Sub, FCM, Mailjet). Home uses fixed Flutter sections, not a server-driven widget engine.

**Dev alignment (2026-10):** Migrations through `015`; gallery recent/favorites (FR-GAL-004); baby profile photo (FR-BABY-006); in-app notifications + FCM writers and weekly digest push (FR-NOTIF); §6.2 home hub on dev. See [building-the-app.md](../engineering/building-the-app.md) for the engineering gate.
