# Intentional dev decisions (accepted gaps)

Some items from the [Oct 2026 open-gaps review](open-gaps.md) are **not bugs for `lanonna-dev`**. They are deliberate tradeoffs for a single-team pre-beta environment. Revisit before **prod** or wide public beta.

### M-21

**`lanonna-automation`** on dev keeps **`roles/editor`**, **`roles/iam.serviceAccountAdmin`**, and **`roles/resourcemanager.projectIamAdmin`**. Prod sets `create_automation_sa = false`.

Local agents, Terraform, and one-off GCP work need broad dev project access without maintaining a long custom role list. Key is personal, never committed. **Revisit:** CI/WIF with a narrow deploy SA for prod; shrink automation to deploy-only roles on dev if abuse is a concern.

### M-20

API and worker runtime SAs use project-level **`roles/secretmanager.secretAccessor`** (all secrets in the project, including `admin-api-key`).

Small secret set; Cloud Run mounts only the secrets each service references in deploy env. Per-secret IAM bindings add Terraform churn with little gain on dev. **Revisit:** prod hardening — bind accessor only on secrets each SA needs.

### H-06

**`/v1/admin/system-announcements`** stays on the same public Cloud Run API as member routes, gated by **`X-Admin-Key`** from Secret Manager (`admin-api-key`). No IAP/private admin service on dev.

Low-traffic admin surface (system announcements); key rotation via Secret Manager; member JWT remains required for all non-admin routes. **Revisit:** public beta or prod — IAP/private admin, rate limits, `secrets.compare_digest`, or split admin to internal-only Run.

### M-53

**`infra/db/clear_dev_test_data.py`** and **`hard_delete_user.py`** remain powerful (wide baby/user deletes, Firebase via ADC) without automated project-id guards.

Dev QA and onboarding retests need fast resets; operators are trusted. Also documented in [operations.md](operations.md). **Revisit:** never run against non-dev; optional explicit `--project lanonna-dev` guard if the team grows.

## Operator expectations

- Use **`lanonnaapp@gmail.com`** or documented human ADC for deploys; automation SA is optional and dev-only ([operations.md](operations.md) service accounts).
- Admin key: Secret Manager `admin-api-key`; never log or commit.
- DB scripts: Cloud SQL Auth Proxy to **dev** only; confirm `gcloud config get-value project` before `clear_dev_test_data` / `hard_delete_user`.

## Code / infra touchpoints

| ID | Where |
|----|--------|
| M-21 | `infra/terraform/modules/platform/iam.tf` (`automation_*`); `environments/dev/main.tf` (`create_automation_sa = true`) |
| M-20 | `infra/terraform/modules/platform/iam.tf` (`runtime_secret_accessor`) |
| H-06 | `services/api/src/lanonna_api/admin_auth.py`, `routers/admin_system_announcements.py`, `deploy.sh` (`--allow-unauthenticated`) |
| M-53 | `infra/db/clear_dev_test_data.py`, `infra/db/hard_delete_user.py` |
