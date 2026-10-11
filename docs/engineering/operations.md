# Operations — GCP, deploy, and dev readiness

**Project:** `lanonna-dev` (Terraform state: `gs://lanonna-dev-terraform-state`). Use account **`lanonnaapp@gmail.com`** for Firebase CLI and Cloud Build deploys.

| Topic | Doc |
|-------|-----|
| Resource inventory, console links | [infra/gcp/SETUP.md](../../infra/gcp/SETUP.md) |
| Day-to-day coding | [development.md](development.md) |
| Design principles | [platform-architecture.md](platform-architecture.md) |

---

## Dev readiness gate

Run before product feature work. Platform plumbing should be **green** first.

```bash
gcloud config set account lanonnaapp@gmail.com
gcloud config set project lanonna-dev

# Optional but recommended (Firebase test user password):
export SMOKE_TEST_PASSWORD='…'

./scripts/apply-dev-run-iam.sh   # after worker deploy
./scripts/verify-dev-prerequisites.sh
```

| Area | Notes |
|------|--------|
| Terraform `lanonna-dev` | `terraform validate` passes; `terraform apply` when module changes — push subs (upload + async commands), **DLQ** on push, CORS, API/worker TokenCreator |
| Cloud Run `api` / `worker` | `services/*/scripts/deploy.sh` |
| Auth + API | Flutter dev or curl with Firebase JWT; `GET /health` |
| Cloud SQL | Migrations through **`027`** — proxy + `apply_migrations.py`; optional `./scripts/verify-dev-migrations.sh` |
| GCS → Pub/Sub → worker | `./scripts/infra-smoke-display-upload.sh` (set `SMOKE_TEST_PASSWORD`) |
| Worker security | **No** `allUsers` on `worker`; Run invoker via `apply-dev-run-iam.sh` |
| Quality gate | `verify-dev-prerequisites.sh` (Flutter analyze/test, API/worker compile); run `pytest` when you touch Python. **GitHub Actions CI is disabled** — [open-gaps.md](open-gaps.md) (M-32) |
| Firebase | Local plist/json + `firebase_options.dart` (see [Flutter (dev)](#flutter-dev) below) |
| Mailjet | Secrets on worker for `send_invite_email` |
| App Check | Code ready; dev deploy defaults `APP_CHECK_ENFORCE=false` — [pre-beta-qa.md](pre-beta-qa.md) |
| FCM | Migration `014`, worker `firebase-admin`, mobile `PushNotificationService`; iOS Push capability |

**Pre-beta blockers:** [open-gaps.md](open-gaps.md).

---

## Environments and Terraform

Path B platform: **`infra/terraform/`** — one **`platform`** module, **`dev`** and **`prod`** environment folders.

| Environment | Project | When |
|-------------|---------|------|
| **dev** | `lanonna-dev` | Now — limited testers |
| **prod** | `lanonna-prod` | Real users (**not created yet**) |

**Terraform manages:** APIs, GCS (+ upload notification), Pub/Sub (**push** subs + DLQ), Cloud SQL, Artifact Registry, Secret Manager **containers**, IAM, Firebase project attachment. Legacy **`infra/gcp/bootstrap.sh`** is deprecated.

**Dev extras:** push subscription **`photo-upload-finalized-push-dev`** (OIDC), display bucket **CORS**, API **TokenCreator** IAM. **Run invoker** on `worker`: `./scripts/apply-dev-run-iam.sh` (gcloud; TF may **403** on `setIamPolicy` — use owner account).

### Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk), [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5, [Flutter](https://docs.flutter.dev/get-started/install)

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project lanonna-dev
gcloud config set project lanonna-dev
gcloud config set account lanonnaapp@gmail.com
```

### Terraform workflow

**First-time / DR:**

```bash
./infra/terraform/scripts/ensure-state-bucket.sh lanonna-dev lanonna-dev-terraform-state
cd infra/terraform/environments/dev
terraform init
../../scripts/import-dev.sh   # only if resources pre-existed
terraform plan
terraform apply               # when plan looks safe
```

**Day-to-day:** `cd infra/terraform/environments/dev && terraform plan` (apply after infra changes).

### Dev vs prod sizing

| Setting | Dev | Prod (`terraform.tfvars.example`) |
|---------|-----|-------------------------------------|
| Cloud SQL | `db-custom-1-3840`, 10 GB zonal | `db-custom-2-7680`, 20+ GB |
| Automation SA (`lanonna-automation`, Editor) | **Yes** (local only) | **No** — CI + WIF later |

### Prod (when you launch)

1. Create **`lanonna-prod`**, link billing.
2. `./infra/terraform/scripts/ensure-state-bucket.sh lanonna-prod lanonna-prod-terraform-state`
3. `cd infra/terraform/environments/prod` → `terraform.tfvars` from example → `terraform init && terraform apply` (fresh apply, no import).

Real users on prod = **new Firebase project + prod flavor**, not renaming dev. See [platform-architecture.md](platform-architecture.md).

---

## Application deploy (dev)

| Service | Cloud Run name | Deploy |
|---------|----------------|--------|
| **API** | `api` | `./services/api/scripts/deploy.sh` |
| **Worker** | `worker` | `./services/worker/scripts/deploy.sh` then **`./scripts/apply-dev-run-iam.sh`** |

Scripts use **Cloud Build** → `us-central1-docker.pkg.dev/lanonna-dev/lanonna/…`. Optional: `USE_LOCAL_DOCKER=1`.

**API deploy wires:** Cloud SQL `lanonna-dev:us-central1:lanonna-db`, secret `db-lanonna-app-password` → `DB_PASSWORD`, `DISPLAY_BUCKET=lanonna-dev-display`, `GCS_SIGNING_SERVICE_ACCOUNT=lanonna-api@lanonna-dev.iam.gserviceaccount.com`.

**GCS signed uploads:** `lanonna-api` needs `roles/iam.serviceAccountTokenCreator` on itself (`run_iam.tf` → `api_self_token_creator`).

**Cloud Build IAM:** If deploy fails, grant default compute / Cloud Build SAs `cloudbuild.builds.builder`, `storage.admin`, `artifactregistry.writer`, `logging.logWriter`, and `run.admin` + `iam.serviceAccountUser` on the Cloud Build SA.

**Deploy order when both change:** apply **migrations** first if needed → **worker** → `apply-dev-run-iam.sh` → **API**. Email templates: `bash scripts/sync-email-templates.sh apply` before worker deploy when templates changed.

**URLs:**

```bash
gcloud run services describe api --region=us-central1 --format='value(status.url)'
gcloud run services describe worker --region=us-central1 --format='value(status.url)'
```

Keep `apps/mobile/flavors/dev.json` **`API_BASE_URL`** in sync ([flavors/README.md](../../apps/mobile/flavors/README.md)).

### Worker URL and Terraform

After worker redeploy, if the hostname changed:

```hcl
# infra/terraform/environments/dev/main.tf
worker_push_endpoint = "https://worker-….us-central1.run.app/pubsub/push"
```

```bash
cd infra/terraform/environments/dev && terraform apply
```

### Worker (Pub/Sub push)

- Push: **`photo-upload-finalized-push-dev`** on **`photo-upload-finalized`** (no pull consumer; failures → DLQ after max attempts — `pubsub.tf`)
- Commands: **`lanonna-async-commands-push-dev`** on **`lanonna-async-commands`**
- Handler: `POST /pubsub/push` — thumbnails, Mailjet invites, notifications/FCM, export, invite cleanup, weekly digest
- Weekly digest: `./scripts/setup-weekly-digest-scheduler.sh` (Sunday 14:00 UTC)
- Expired invites: `./scripts/setup-expired-invites-scheduler.sh`
- **Push auth:** OIDC; Run invoker via `apply-dev-run-iam.sh` after each worker deploy
- **FCM:** Worker SA may need **`roles/firebasecloudmessaging.admin`**

**Infra smoke:**

```bash
export SMOKE_TEST_PASSWORD='…'
./scripts/infra-smoke-display-upload.sh
```

---

## Database migrations

Schema: **`infra/db/migrations/`** (`001`–`027`). See [migrations/README.md](../../infra/db/migrations/README.md).

```bash
cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5432   # or 5433
export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-lanonna-app-password --project=lanonna-dev)
cd infra/db
python3 -m venv .venv && .venv/bin/pip install 'psycopg[binary]'
DB_PASSWORD="$PGPASSWORD" DB_PORT=5432 .venv/bin/python apply_migrations.py
./scripts/verify-dev-migrations.sh   # from repo root, PGPASSWORD set
```

Secrets (values in Secret Manager only): `db-lanonna-app-password`, `database-url`, `db-postgres-root-password`, `admin-api-key` (add version via `gcloud` after first apply if empty).

**Retest onboarding:** `clear_dev_test_data.py --email you@example.com --reset-onboarding` — [development.md](development.md).

---

## Flutter (dev)

- Package: `com.lanonna.lanonna`; Firebase **`lanonna-dev`**
- Gitignored: `google-services.json`, `GoogleService-Info.plist`
- Checked in: `firebase_options.dart` (or `flutterfire configure`)
- Flavor: `apps/mobile/flavors/dev.json` — **`API_BASE_URL`**, `APP_ENV=dev`

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json
```

Create **Email/Password** users in Firebase console (or smoke user `lanonna.dev.smoke@test.com`). iOS: `cd ios && pod install` once.

---

## Ship builds and beta gates

| Step | Command |
|------|---------|
| Universal APK → Drive | `./scripts/ship_release_apk_to_drive.sh` → `lanonna_app.apk` |
| x86_64 APK → Drive / emulator | `./scripts/ship_release_apk_x86_64_to_drive.sh` → `lanonna_app_x86_64.apk`; `adb install -r` |
| Tests + optional API deploy | `./scripts/run-beta-gate.sh` |
| Force-update | Migration `020`; `app_versions` + `GET /v1/app/version` |
| Device QA before wide beta | [pre-beta-qa.md](pre-beta-qa.md) |

---

## Service accounts

| Account | Purpose |
|---------|---------|
| `lanonna-automation@lanonna-dev.iam.gserviceaccount.com` | Dev automation (Editor — **not for prod**) |
| `lanonna-api@lanonna-dev.iam.gserviceaccount.com` | Cloud Run **api** |
| `lanonna-worker@lanonna-dev.iam.gserviceaccount.com` | Cloud Run **worker** |

Optional local automation key (never commit): `~/Neo_Workspace/secrets/lanonna/gcp-automation-key.json`

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/Neo_Workspace/secrets/lanonna/gcp-automation-key.json"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
gcloud config set project lanonna-dev
```

Switch back for interactive work: `gcloud config set account lanonnaapp@gmail.com`

---

## Manual checklist

| Item | Action |
|------|--------|
| Firebase Blaze | Done on `lanonna-dev` |
| Email/Password Auth | Enabled; smoke user via `SMOKE_TEST_PASSWORD` |
| Billing budgets | $50 / $150 / $300 on dev |
| Mailjet secrets | Set in Secret Manager — rotate if exposed |
| App Check | Debug tokens for QA; enforce before wide beta |
| Google / Apple sign-in | Enable in Firebase when product-ready |

---

## Security

- No SA JSON, `terraform.tfvars` secrets, or Firebase plist/json in git.
- Dev worker: **OIDC push**, no `allUsers`; re-run `apply-dev-run-iam.sh` after worker deploy.
- Terraform creates Secret Manager **IDs** only; values via `gcloud` / console.

---

## Console links (`lanonna-dev`)

- [GCP project](https://console.cloud.google.com/home/dashboard?project=lanonna-dev)
- [Firebase](https://console.firebase.google.com/project/lanonna-dev/overview)
- [Cloud SQL](https://console.cloud.google.com/sql/instances/lanonna-db?project=lanonna-dev)
- [Cloud Run](https://console.cloud.google.com/run?project=lanonna-dev)
- [Cloud Build](https://console.cloud.google.com/cloud-build/builds?project=lanonna-dev)
- [Secret Manager](https://console.cloud.google.com/security/secret-manager?project=lanonna-dev)
