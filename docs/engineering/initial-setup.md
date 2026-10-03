# Initial GCP & infrastructure setup

**`lanonna-dev`** is provisioned and managed by **Terraform**. State is in **`gs://lanonna-dev-terraform-state`**. Run **`terraform plan`** in dev after infra changes; some principals see **403** on Pub/Sub IAM policy refresh (use owner account `lanonnaapp@gmail.com`). Gate for app work: **`./scripts/verify-dev-prerequisites.sh`** ([building-the-app.md](building-the-app.md)).

| Topic | Doc |
|-------|-----|
| Resource inventory, console links | [infra/gcp/SETUP.md](../infra/gcp/SETUP.md) |
| Platform architecture | [platform-architecture.md](platform-architecture.md) |
| Day-to-day dev layout | [development.md](development.md) |

---

## Two environments (dev now, prod later)

Path B GCP platform lives in **`infra/terraform/`** — one **`platform`** module, two environment folders:

| Environment | Project | When |
|-------------|---------|------|
| **dev** | `lanonna-dev` | Now — limited testers, smaller SQL |
| **prod** | `lanonna-prod` | When launching real users (**not created yet**) |

### What Terraform manages

- **`infra/terraform/modules/platform`** — APIs, GCS (+ upload notification), Pub/Sub topic + **pull** subscription `photo-upload-finalized-worker`, Cloud SQL, Artifact Registry, Secret Manager **containers**, IAM (api/worker + optional automation SA), Firebase project attachment
- **`infra/terraform/environments/dev`** — `lanonna-dev`, `db-custom-1-3840`, `create_automation_sa = true`
- **`infra/terraform/environments/prod`** — stub + `terraform.tfvars.example` (apply when `lanonna-prod` exists)

Legacy **`infra/gcp/bootstrap.sh`** is deprecated — do not add resources there.

**Terraform (dev):** push subscription **`photo-upload-finalized-push-dev`** (OIDC), display bucket **CORS**, API **TokenCreator** IAM. **Run invoker** on `worker`: `./scripts/apply-dev-run-iam.sh` (gcloud; TF may 403 on `setIamPolicy`).

---

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk) (`gcloud`)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- [Flutter](https://docs.flutter.dev/get-started/install) (mobile app)
- Human login with Owner on the project:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project lanonna-dev
gcloud config set project lanonna-dev
gcloud config set account lanonnaapp@gmail.com
```

Use **`lanonnaapp@gmail.com`** for Firebase CLI and **Cloud Build deploys** (`gcloud builds submit` / `deploy.sh`). The automation service account key often **cannot** trigger Cloud Build uploads.

Firebase-related Terraform may need `billing_project = lanonna-dev` on providers (already set in repo).

---

## Dev — Terraform workflow

**First-time** (already done for this repo; keep for new machines or disaster recovery):

```bash
./infra/terraform/scripts/ensure-state-bucket.sh lanonna-dev lanonna-dev-terraform-state
cd infra/terraform/environments/dev
terraform init
../../scripts/import-dev.sh   # only if resources pre-existed
terraform plan
terraform apply               # only when plan looks safe
```

**Day-to-day:**

```bash
cd infra/terraform/environments/dev
terraform plan
```

---

## Application services (dev — deployed)

| Service | Cloud Run name | URL |
|---------|----------------|-----|
| **API** (FastAPI) | `api` | `gcloud run services describe api --region=us-central1 --format='value(status.url)'` |
| **Worker** (Pub/Sub push) | `worker` | `gcloud run services describe worker --region=us-central1 --format='value(status.url)'` |

After worker redeploy, align `worker_push_endpoint` in `infra/terraform/environments/dev/main.tf` if the hostname changed, then `terraform apply`.

### API endpoints

The live surface is larger than the bootstrap routes below. **Authoritative list:** [development.md](development.md) (profile, onboarding, babies, invitations, photos/gallery, events/calendar, registry, fun, home-summary).

| Method | Path | Auth |
|--------|------|------|
| GET | `/health` | Public |
| GET | `/v1/me`, GET/PATCH `/v1/profile` | Firebase ID token (`Authorization: Bearer …`) |
| GET, POST, PATCH | `/v1/babies`, `…/home-summary`, onboarding, invitations | JWT + membership / owner rules |
| POST | `/v1/photos/init` | JWT (owner upload init → signed PUT to `display/`) |
| GET/PATCH/DELETE | `/v1/babies/{id}/photos…`, `…/events…`, `…/registry…`, `…/fun…` | JWT (see development.md) |
| POST | `/v1/uploads/display/signed-url` | JWT; legacy/smoke signed **PUT** to `lanonna-dev-display` |

### Deploy (no local Docker required)

```bash
gcloud config set account lanonnaapp@gmail.com
gcloud config set project lanonna-dev

./services/api/scripts/deploy.sh
./services/worker/scripts/deploy.sh
```

Scripts use **Cloud Build** to push images to `us-central1-docker.pkg.dev/lanonna-dev/lanonna/…`, then deploy Cloud Run. Optional: `USE_LOCAL_DOCKER=1` if Docker is installed.

**API deploy** also wires:

- Cloud SQL instance `lanonna-dev:us-central1:lanonna-db`
- Secret `db-lanonna-app-password` → env `DB_PASSWORD`
- `DISPLAY_BUCKET=lanonna-dev-display`, `GCS_SIGNING_SERVICE_ACCOUNT=lanonna-api@lanonna-dev.iam.gserviceaccount.com`

**GCS signed uploads (API):** `lanonna-api` needs `roles/iam.serviceAccountTokenCreator` on itself (Terraform: `run_iam.tf` → `api_self_token_creator`) so Cloud Run can mint V4 signed URLs without a JSON key.

**Cloud Build:** `cloudbuild.googleapis.com` is enabled on dev. If source deploy fails with IAM errors on the default compute SA, grant Cloud Build / compute default SAs `cloudbuild.builds.builder`, `storage.admin`, `artifactregistry.writer`, `logging.logWriter` (and `run.admin` + `iam.serviceAccountUser` on the Cloud Build SA for deploy steps).

### Worker (dev Pub/Sub push)

- Push subscription: **`photo-upload-finalized-push-dev`** on topic **`photo-upload-finalized`**
- Handler: `POST /pubsub/push` — **`send_invite_email`** (Mailjet), **`notify_fan_out` / `notify_user` / `weekly_notification_digest`** (in-app + FCM), **GCS finalize** → thumbnail + `photos.status = ready` + `photo_shared` + member notifications
- Weekly digest: `./scripts/setup-weekly-digest-scheduler.sh` (Sunday 14:00 UTC → Pub/Sub `weekly_notification_digest` on worker topic)
- **Mobile push:** `firebase_messaging` + token register on sign-in (`PUT /v1/me/device-tokens`). iOS: enable **Push Notifications** in Xcode. Worker SA: **`roles/firebasecloudmessaging.admin`** if FCM sends fail in dev.
- **Push auth:** OIDC with `lanonna-worker`; Run invoker IAM via `./scripts/apply-dev-run-iam.sh` after deploy.

Infra smoke (signed URL → GCS → Pub/Sub → worker):

```bash
export SMOKE_TEST_PASSWORD='…'   # Firebase test user
./scripts/infra-smoke-display-upload.sh
```

---

## Database migrations

Schema lives in **`infra/db/migrations/`** (`001`–`015`). See [infra/db/migrations/README.md](../../infra/db/migrations/README.md) (through `system_announcements` in `015`).

From a laptop (with [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-auth-proxy)):

```bash
cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5432   # or --port 5433
export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-lanonna-app-password --project=lanonna-dev)
cd infra/db
python3 -m venv .venv && .venv/bin/pip install 'psycopg[binary]'
DB_PASSWORD="$PGPASSWORD" DB_PORT=5432 .venv/bin/python apply_migrations.py
```

Manual single file: `psql -h 127.0.0.1 -p 5432 -U lanonna_app -d lanonna -f infra/db/migrations/006_home_activity.sql`.

**Retest onboarding / new baby on dev:** `clear_dev_test_data.py --email you@example.com --reset-onboarding` (see [development.md](development.md)).

Secrets: **`db-lanonna-app-password`**, **`database-url`**, **`db-postgres-root-password`** (values in Secret Manager only).

---

## Flutter (dev)

- **Package / bundle:** `com.lanonna.lanonna`
- **Firebase project:** `lanonna-dev` (Email/Password Auth enabled)
- **Config files (gitignored, local):** `apps/mobile/android/app/google-services.json`, `apps/mobile/ios/Runner/GoogleService-Info.plist`
- **Checked in:** `apps/mobile/lib/firebase_options.dart` (or regenerate with `flutterfire configure` after `gem install xcodeproj`)
- **Dev flavor:** `apps/mobile/flavors/dev.json` — API base URL + `APP_ENV=dev`

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json
```

**Manual:** Create at least one **Email/Password** user in [Firebase Authentication](https://console.firebase.google.com/project/lanonna-dev/authentication/users) for sign-in testing. iOS may need `cd ios && pod install` once.

---

## Dev vs prod sizing

| Setting | Dev (`environments/dev`) | Prod (`terraform.tfvars.example`) |
|---------|--------------------------|-----------------------------------|
| Cloud SQL tier | `db-custom-1-3840` | `db-custom-2-7680` (adjust as needed) |
| Disk | 10 GB | 20+ GB |
| HA | Zonal | Zonal until SLA needs regional |
| Automation SA (`lanonna-automation`, Editor) | **Yes** — local/agent only | **No** — CI + WIF later |

---

## Prod (when you launch)

1. Create GCP project **`lanonna-prod`**, link billing.
2. `./infra/terraform/scripts/ensure-state-bucket.sh lanonna-prod lanonna-prod-terraform-state`
3. `cd infra/terraform/environments/prod` → copy `terraform.tfvars.example` → `terraform.tfvars`
4. `terraform init && terraform apply` — **fresh apply**, no import.

Real users on prod = **new Firebase project + prod flavor**, not renaming dev. See [platform-architecture.md](platform-architecture.md).

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

Switch back for interactive work: `gcloud config set account lanonnaapp@gmail.com`

---

## Manual / ongoing checklist

| Item | Status / action |
|------|-----------------|
| Firebase Blaze on `lanonna-dev` | Done |
| Email/Password Auth | Enabled — add users in console, or use dev smoke account `lanonna.dev.smoke@test.com` (password via `SMOKE_TEST_PASSWORD` / team store) |
| Billing budgets ($50 / $150 / $300) | Created for `lanonna-dev` |
| Mailjet secrets in Secret Manager | Versions set — **rotate** if keys were ever exposed |
| FCM | In use on dev (mobile + worker); Crashlytics | — |
| App Check | Flutter `firebase_app_check` + API `X-Firebase-AppCheck` | Enable in Firebase Console; register **debug tokens** from emulator log; deploy API with `APP_CHECK_ENFORCE=true` |
| Google / Apple sign-in | Enable in Firebase when product-ready |

---

## Security

- Do not commit service account JSON, `terraform.tfvars` with secrets, or Firebase plist/json (gitignored).
- Rotate `lanonna-automation` key if exposed; no broad automation SA in prod.
- Terraform manages Secret Manager **IDs** only; **values** stay in Secret Manager. Platform module `secret_ids` includes **`admin-api-key`** (API deploy: `ADMIN_API_KEY=admin-api-key:latest` in `services/api/scripts/deploy.sh`); add a secret **version** via `gcloud` after first apply if the container is empty.
- Dev worker uses **OIDC push** (no `allUsers`); re-run `./scripts/apply-dev-run-iam.sh` after worker deploy. Harden further for prod (TF-managed Run IAM, no public API surface beyond `/health`).

---

## Console links (`lanonna-dev`)

- [GCP project](https://console.cloud.google.com/home/dashboard?project=lanonna-dev)
- [Firebase](https://console.firebase.google.com/project/lanonna-dev/overview)
- [Cloud SQL](https://console.cloud.google.com/sql/instances/lanonna-db?project=lanonna-dev)
- [Cloud Run](https://console.cloud.google.com/run?project=lanonna-dev)
- [Cloud Build](https://console.cloud.google.com/cloud-build/builds?project=lanonna-dev)
- [Secret Manager](https://console.cloud.google.com/security/secret-manager?project=lanonna-dev)
