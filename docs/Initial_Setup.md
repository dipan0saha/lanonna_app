# Initial GCP & infrastructure setup

**`lanonna-dev`** is provisioned and managed by **Terraform**. State is in **`gs://lanonna-dev-terraform-state`**. As of setup completion, **`terraform plan`** in dev should show **no changes** when infrastructure matches the repo.

| Topic | Doc |
|-------|-----|
| Resource names, console links, manual Firebase steps | [infra/gcp/SETUP.md](../infra/gcp/SETUP.md) |
| Architecture (Path B) | [path_b_gcp_stack.md](path_b_gcp_stack.md) |
| Local dev layout | [development.md](development.md) |

---

## Two environments (dev now, prod later)

Path B GCP platform lives in **`infra/terraform/`** — one **`platform`** module, two environment folders:

| Environment | Project | When |
|-------------|---------|------|
| **dev** | `lanonna-dev` | Now — limited testers, smaller SQL |
| **prod** | `lanonna-prod` | When launching real users (**not created yet**) |

Console-only work (Firebase Auth providers, Blaze upgrade, Mailjet values, mobile plist/json) is listed in [infra/gcp/SETUP.md](../infra/gcp/SETUP.md).

### What Terraform manages

- **`infra/terraform/modules/platform`** — APIs, GCS (+ upload notification), Pub/Sub, Cloud SQL, Artifact Registry, Secret Manager **containers**, IAM (api/worker + optional automation SA), Firebase project attachment
- **`infra/terraform/environments/dev`** — `lanonna-dev`, `db-custom-1-3840`, `create_automation_sa = true`
- **`infra/terraform/environments/prod`** — stub + `terraform.tfvars.example` (apply when `lanonna-prod` exists)

Legacy **`infra/gcp/bootstrap.sh`** is deprecated — do not add resources there.

---

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk) (`gcloud`)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- Human login with Owner on the project:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project lanonna-dev
gcloud config set project lanonna-dev
```

Use **`lanonnaapp@gmail.com`** (or your project owner) for Firebase-related Terraform operations; providers use `billing_project = lanonna-dev`.

---

## Dev — Terraform workflow

**First-time** (already done for this repo; keep for new machines or disaster recovery):

```bash
# 1) Remote state bucket (once)
./infra/terraform/scripts/ensure-state-bucket.sh lanonna-dev lanonna-dev-terraform-state

# 2) Init
cd infra/terraform/environments/dev
terraform init

# 3) Import (only if resources were created outside Terraform)
../../scripts/import-dev.sh

# 4) Reconcile
terraform plan
terraform apply   # only when plan looks safe
```

**Day-to-day:**

```bash
cd infra/terraform/environments/dev
terraform plan
```

---

## Dev vs prod sizing

| Setting | Dev (in `environments/dev`) | Prod (`terraform.tfvars.example`) |
|---------|-----------------------------|-----------------------------------|
| Cloud SQL tier | `db-custom-1-3840` | `db-custom-2-7680` (adjust as needed) |
| Disk | 10 GB | 20+ GB |
| HA | Zonal | Zonal until SLA needs regional |
| Automation SA (`lanonna-automation`, Editor) | **Yes** — local/agent only | **No** — use CI + Workload Identity Federation later |

---

## Prod (when you launch)

1. Create GCP project **`lanonna-prod`**, link billing.
2. `./infra/terraform/scripts/ensure-state-bucket.sh lanonna-prod lanonna-prod-terraform-state`
3. `cd infra/terraform/environments/prod`
4. Copy `terraform.tfvars.example` → `terraform.tfvars` (globally unique bucket names).
5. `terraform init && terraform apply` — **fresh apply**, no import.

Switching real users to prod is a **new Firebase project + prod app flavor**, not renaming dev. See [path_b_gcp_stack.md](path_b_gcp_stack.md) for architecture; migrate only if you had real users on dev.

---

## Flutter / runtime config

Use **flavors** (`dev` / `prod`) pointing at:

- Firebase project (same ID as GCP project per env)
- Cloud Run API URL (per env)
- GCS buckets from `terraform output`

---

## Service accounts & automation key

| Account | Purpose |
|---------|---------|
| `lanonna-automation@lanonna-dev.iam.gserviceaccount.com` | Dev automation (Editor — **not for prod**) |
| `lanonna-api@lanonna-dev.iam.gserviceaccount.com` | Cloud Run **api** runtime |
| `lanonna-worker@lanonna-dev.iam.gserviceaccount.com` | Cloud Run **worker** runtime |

**Key path (local only, never commit):**

```text
~/Neo_Workspace/secrets/lanonna/gcp-automation-key.json
```

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/Neo_Workspace/secrets/lanonna/gcp-automation-key.json"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
gcloud config set project lanonna-dev
```

Switch back to your user account for interactive work: `gcloud config set account lanonnaapp@gmail.com`

---

## Manual steps (still required)

1. **Firebase Blaze** — [Usage & billing](https://console.firebase.google.com/project/lanonna-dev/usage/details)
2. **Firebase Auth** — Email/Password (+ Google / Apple when ready)
3. **FCM, Crashlytics, Analytics, Remote Config, App Check** — enable as you build
4. **Billing budgets** — e.g. $50 / $150 / $300 in [Billing budgets](https://console.cloud.google.com/billing/budgets)
5. **Mailjet** — replace `REPLACE_ME` in Secret Manager `mailjet-api-key` / `mailjet-api-secret`
6. **Flutter** — register apps in Firebase; `google-services.json` / `GoogleService-Info.plist` in `apps/mobile` (gitignored)

---

## Cloud SQL from laptop

```bash
cloud-sql-proxy lanonna-dev:us-central1:lanonna-db
gcloud secrets versions access latest --secret=database-url --project=lanonna-dev
```

---

## Security

- Do not commit service account JSON keys or `terraform.tfvars` with secrets.
- Rotate `lanonna-automation` key if exposed; **no** broad automation SA in prod.
- Terraform manages Secret Manager **IDs** only; **values** (DB URL, Mailjet) stay in Secret Manager.

---

## Console links (`lanonna-dev`)

- [GCP project](https://console.cloud.google.com/home/dashboard?project=lanonna-dev)
- [Firebase](https://console.firebase.google.com/project/lanonna-dev/overview)
- [Cloud SQL](https://console.cloud.google.com/sql/instances/lanonna-db?project=lanonna-dev)
- [Cloud Run](https://console.cloud.google.com/run?project=lanonna-dev)
- [Secret Manager](https://console.cloud.google.com/security/secret-manager?project=lanonna-dev)
