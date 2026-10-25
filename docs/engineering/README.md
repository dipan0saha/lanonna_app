# Engineering documentation

| Document | Use when |
|----------|----------|
| [development.md](development.md) | Daily work — repo layout, API routes, mobile conventions, DB tools, performance |
| [mobile-prototype-parity.md](mobile-prototype-parity.md) | Shared mobile theme tokens/widgets aligned with the HTML prototype ([`nonna_combined_prototype.html`](../prototype/nonna_combined_prototype.html)) |
| [operations.md](operations.md) | GCP/Terraform, deploy, migrations, dev readiness, ship APK / beta scripts |
| [prod-launch-plan.md](prod-launch-plan.md) | **Source of truth** for creating `lanonna-prod` and launching on Google Play: phases 0–14 checklist, Dipan's inputs (D1–D23) and manual steps (M1–M22), email provider and domain options |
| [pre-prod-consolidation.md](pre-prod-consolidation.md) | What to consolidate before `lanonna-prod` (migrations squash vs wiring) |
| [mobile-prod-flavor-and-crashlytics.md](mobile-prod-flavor-and-crashlytics.md) | Mobile prod flavor, signing, App Links, Crashlytics |
| [platform-architecture.md](platform-architecture.md) | Stack principles, flows, cost model, security checklist |
| [pre-beta-qa.md](pre-beta-qa.md) | Manual device QA before widening beta |
| [change-safety.md](change-safety.md) | Local pre-merge gate, impact analysis, regression-test rules (replaces GitHub Actions CI) |
| [open-gaps.md](open-gaps.md) | Open pre-beta engineering gaps, test health snapshot, Oct 16 2026 architecture-review outcomes |
| [intentional-dev-decisions.md](intentional-dev-decisions.md) | Accepted dev-only security/IAM/ops tradeoffs (not open work) |
| [facebook-login-implementation-plan.md](facebook-login-implementation-plan.md) | Deferred Facebook OAuth plan (not in v1) |

Product scope: [../product/requirements.md](../product/requirements.md).

**Dev snapshot:** `lanonna-dev` on Cloud Run; SQL schema per the [migrations README](../../infra/db/migrations/README.md); **pre-merge gate** **`./scripts/premerge_check.sh`** (required before merge); broader readiness **`./scripts/verify-dev-prerequisites.sh`**; pre-beta blockers in [open-gaps.md](open-gaps.md).
