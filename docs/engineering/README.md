# Engineering documentation

| Document | Use when |
|----------|----------|
| [development.md](development.md) | Daily work — repo layout, API routes, mobile conventions, DB tools, performance |
| [operations.md](operations.md) | GCP/Terraform, deploy, migrations, dev readiness, ship APK / beta scripts |
| [platform-architecture.md](platform-architecture.md) | Stack principles, flows, cost model, security checklist |
| [pre-beta-qa.md](pre-beta-qa.md) | Manual device QA before widening beta |
| [open-gaps.md](open-gaps.md) | Open pre-beta engineering gaps (Oct 2026 review) |
| [intentional-dev-decisions.md](intentional-dev-decisions.md) | Accepted dev-only security/IAM/ops tradeoffs (not open work) |

Product scope: [../product/requirements.md](../product/requirements.md).

**Dev snapshot:** `lanonna-dev` on Cloud Run; SQL schema per the [migrations README](../../infra/db/migrations/README.md); local quality gate **`./scripts/verify-dev-prerequisites.sh`**; pre-beta blockers in [open-gaps.md](open-gaps.md).
