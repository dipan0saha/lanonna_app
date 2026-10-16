# Engineering documentation

| Document | Use when |
|----------|----------|
| [development.md](development.md) | Daily work — repo layout, API routes, mobile conventions, DB tools, performance |
| [mobile-prototype-parity.md](mobile-prototype-parity.md) | Shared mobile theme/widgets aligned with the HTML prototype |
| [operations.md](operations.md) | GCP/Terraform, deploy, migrations, dev readiness, ship APK / beta scripts |
| [platform-architecture.md](platform-architecture.md) | Stack principles, flows, cost model, security checklist |
| [pre-beta-qa.md](pre-beta-qa.md) | Manual device QA before widening beta |
| [open-gaps.md](open-gaps.md) | Open pre-beta engineering gaps (health snapshot updated Oct 2026) |
| [intentional-dev-decisions.md](intentional-dev-decisions.md) | Accepted dev-only security/IAM/ops tradeoffs (not open work) |
| [facebook-login-implementation-plan.md](facebook-login-implementation-plan.md) | Deferred Facebook OAuth plan (not in v1) |

Product scope: [../product/requirements.md](../product/requirements.md).

**Dev snapshot:** `lanonna-dev` on Cloud Run; SQL schema per the [migrations README](../../infra/db/migrations/README.md); local quality gate **`./scripts/verify-dev-prerequisites.sh`**; pre-beta blockers in [open-gaps.md](open-gaps.md).
