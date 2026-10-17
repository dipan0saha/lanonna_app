# Product documentation

| Document | Description |
|----------|-------------|
| [requirements.md](requirements.md) | La Nonna product requirements (PRD): features, roles, IA, FR/NFR IDs, and acceptance traceability |

## How this fits the repo

- **What to build (product):** [requirements.md](requirements.md)
- **How to run the platform:** [platform-architecture.md](../engineering/platform-architecture.md)
- **When engineering is unblocked:** [operations.md](../engineering/operations.md)
- **Day-to-day dev:** [development.md](../engineering/development.md)

**Status:** Requirements v1 (draft) — Path B GCP (Firebase Auth, Cloud Run API/worker, Cloud SQL, GCS, Pub/Sub, FCM, Mailjet). Home uses fixed Flutter sections, not a server-driven widget engine.

**Dev alignment (2026-10):** Schema per [infra/db/migrations/README.md](../../infra/db/migrations/README.md) (through `037` structured notification type/actor); gallery recent/favorites (FR-GAL-004); comment edit (FR-GAL-007) and photo baby tags v1 (FR-GAL-008); baby profile photo (FR-BABY-006); in-app notifications + FCM writers and weekly digest push (FR-NOTIF); §6.2 slim home hub on dev (#67); calendar day selection + shared event lists; invite email delivery status + resend (#62); product HTML typography (Baloo 2 + Inter) on Hosting, legal, and Mailjet templates; core **AppToggleChip** / **AppRemovableChip** (no Material chips); prototype-parity theme and shared widgets ([mobile-prototype-parity.md](../engineering/mobile-prototype-parity.md)); all UI copy in ARB, enforced by an AST guard in CI (FR-SET-002); Fun names and predictions read-only after birth (FR-GAM-001 / FR-GAM-004); FR-HOME-002 via `BabyContextReload` on shell tabs + `resolveSelectedBaby` / `resolveOwnerBaby`. See [operations.md](../engineering/operations.md) for the dev readiness gate.
