# Infrastructure (Terraform)

Path B GCP platform is defined in **`infra/terraform/`** — one **`platform`** module, two environments:

| Environment | Project | When |
|-------------|---------|------|
| **dev** | `lanonna-dev` | Now — limited testers, smaller SQL |
| **prod** | `lanonna-prod` | When launching real users (not created yet) |

Console-only steps (Firebase Auth providers, Blaze upgrade, Mailjet values, mobile plist/json) stay in [infra/gcp/SETUP.md](../infra/gcp/SETUP.md).

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk) (`gcloud`)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- Human login with Owner on the project: `gcloud auth application-default login` and `gcloud config set project lanonna-dev`

## Dev — first-time Terraform

```bash
# 1) Remote state bucket (once)
./infra/terraform/scripts/ensure-state-bucket.sh lanonna-dev lanonna-dev-terraform-state

# 2) Init
cd infra/terraform/environments/dev
terraform init

# 3) Import existing manual bootstrap (lanonna-dev already provisioned)
../../scripts/import-dev.sh

# 4) Reconcile
terraform plan
terraform apply   # only when plan looks safe (mostly IAM / API no-ops)
```

## Dev sizing (intentionally smaller)

| Setting | Dev (`terraform.tfvars` in code) | Prod (example) |
|---------|----------------------------------|----------------|
| Cloud SQL tier | `db-custom-1-3840` | `db-custom-2-7680` (adjust in prod tfvars) |
| Disk | 10 GB | 20+ GB |
| HA | Zonal | Zonal until SLA needs regional |
| Automation SA | **Yes** (Editor — local/agent only) | **No** — use CI + WIF later |

## Prod (later)

1. Create GCP project `lanonna-prod`, link billing.
2. `ensure-state-bucket.sh lanonna-prod lanonna-prod-terraform-state`
3. `cd infra/terraform/environments/prod`
4. Copy `terraform.tfvars.example` → `terraform.tfvars`, edit bucket names (globally unique).
5. `terraform init && terraform apply` (fresh apply — no import).

## Flutter / runtime config

Use **flavors** (`dev` / `prod`) pointing at:

- Firebase project (same ID as GCP project)
- Cloud Run API URL (per env)
- GCS buckets from `terraform output`

## Deprecations

- **`infra/gcp/bootstrap.sh`** — legacy; do not add resources there. Use Terraform.

## Security

- Do not commit service account JSON keys or `terraform.tfvars` with secrets.
- Rotate `lanonna-automation` key if exposed; remove automation SA in prod.
- Secret **values** (DB URL, Mailjet) remain in Secret Manager; Terraform manages secret **IDs** only.
