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
| Cloud SQL | All migrations applied — proxy + `apply_migrations.py`; `./scripts/verify-dev-migrations.sh` checks every file in `infra/db/migrations/` is recorded |
| GCS → Pub/Sub → worker | `./scripts/infra-smoke-display-upload.sh` (set `SMOKE_TEST_PASSWORD`) |
| Worker security | **No** `allUsers` on `worker`; Run invoker via `apply-dev-run-iam.sh` |
| Quality gate | `verify-dev-prerequisites.sh` (Flutter analyze/test, API/worker compile); run `pytest` when you touch Python |
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

**Terraform manages:** APIs, GCS (+ upload notification), Pub/Sub (**push** subs + DLQ topic, retention subscription, and service-agent IAM), Cloud SQL, Artifact Registry, Secret Manager **containers**, IAM, Firebase project attachment. The legacy `infra/gcp/bootstrap.sh` has been removed.

**Dev extras:** push subscriptions **`photo-upload-finalized-push-dev`** / **`lanonna-async-commands-push-dev`** (OIDC); push URL is read from live Cloud Run **`worker`** on `terraform apply` (override with `worker_push_endpoint` if needed). **Run invoker** for Pub/Sub is in Terraform (`run_iam.tf`); run `./scripts/apply-dev-run-iam.sh` after worker deploy to remove **`allUsers`** and reconcile IAM if apply lacked `setIamPolicy`.

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

**Build context (M-48):** `gcloud builds submit` uses the **repo root** as source. Root [`.gcloudignore`](../../.gcloudignore) whitelists only `packages/` and `services/` (plus secret/cache exclusions); root [`.dockerignore`](../../.dockerignore) matches for local Docker. To inspect what would upload: `gcloud meta list-files-for-upload .` from the repo root. If a Dockerfile starts `COPY`ing paths outside those trees, extend both ignore files.

**API deploy wires:** Cloud SQL `lanonna-dev:us-central1:lanonna-db`, secret `db-lanonna-app-password` → `DB_PASSWORD`, `DISPLAY_BUCKET=lanonna-dev-display`, `GCS_SIGNING_SERVICE_ACCOUNT=lanonna-api@lanonna-dev.iam.gserviceaccount.com`.

**GCS signed uploads:** `lanonna-api` needs `roles/iam.serviceAccountTokenCreator` on itself (`run_iam.tf` → `api_self_token_creator`).

**Cloud Build IAM:** If deploy fails, grant default compute / Cloud Build SAs `cloudbuild.builds.builder`, `storage.admin`, `artifactregistry.writer`, `logging.logWriter`, and `run.admin` + `iam.serviceAccountUser` on the Cloud Build SA.

**Deploy order when both change:** apply **migrations** first if needed → **worker** → `apply-dev-run-iam.sh` → **API**. Email templates: `bash scripts/sync-email-templates.sh apply` before worker deploy when templates changed.

**Worker sender (#43):** `MAILJET_FROM_EMAIL` is configuration, not a secret. `services/worker/scripts/deploy.sh` uses the environment variable when it is set, otherwise reads `infra/env/dev.worker.env` (`lanonnaapp@gmail.com`, display name `La Nonna`) without executing it. Values with spaces in that file are quoted. The sender check runs before Cloud Build. Deploy and worker startup both refuse an empty sender and `hello@lanonna.app` (Mailjet returns HTTP 200 for that address and drops the message). A Mailjet HTTP 200 whose `Messages[0].Status` is not `success` is a send failure: the invite claim is released and `email_sent_at` is not set.

**Worker invite link and export signing:** `deploy.sh` sets `INVITE_DEEP_LINK_BASE=https://${project_id}.firebaseapp.com` and `GCS_SIGNING_SERVICE_ACCOUNT=lanonna-worker@${project_id}.iam.gserviceaccount.com`. Export media URLs need `lanonna-worker` to be `roles/iam.serviceAccountTokenCreator` on itself (`run_iam.tf` `worker_self_token_creator`, also granted by `./scripts/apply-dev-run-iam.sh`). Startup rejects an invite base that is not `https://`, and rejects a `lanonna-dev` host when `ENVIRONMENT` is not `dev`.

**Invite landing (Firebase Hosting):** from the repo root, after the API is deployed (`--allow-unauthenticated`):

```bash
# Fingerprint of the cert that signs the Android app you install.
# Omit ANDROID_SHA256 to read ~/.android/debug.keystore (alias androiddebugkey).
# APPLE_TEAM_ID is optional; without it iOS stays on the web fallback.
ANDROID_SHA256='AA:BB:…' APPLE_TEAM_ID='XXXXXXXXXX' \
  bash scripts/deploy-invite-hosting.sh
```

The script enables `firebasehosting.googleapis.com`, renders `assetlinks.json` and `apple-app-site-association`, runs `firebase deploy --only hosting` from `hosting/` (serves `/invite`, `/email-verified`, shared [`lanonna-type.css`](../../hosting/public/css/lanonna-type.css)), and grants `service-${PROJECT_NUMBER}@gcp-sa-firebasehosting.iam.gserviceaccount.com` `roles/run.invoker` on Cloud Run `api` so the `/v1/invitations/preview` rewrite works. `hosting/firebase.json` must not ignore `**/.*`: that default drops `.well-known`, so Android App Links and the Apple association file would never be published. That service account does not exist until Hosting is enabled, so it is not in `apply-dev-run-iam.sh`. Re-run is safe. Play Store `https://play.google.com/store/apps/details?id=com.lanonna.lanonna` may 404 until the listing exists; the page says to ask the inviter. After install, the person opens the **same email link** again (no install referrer). Prod later: point the Android manifest host, iOS entitlements, and `INVITE_DEEP_LINK_BASE` at the prod `firebaseapp.com` host.

**Auth email branding:** from the repo root, with `gcloud` ADC for `lanonna-dev`:

```bash
bash scripts/configure-firebase-auth-email-project.sh apply
bash scripts/configure-firebase-auth-email-project.sh check
bash scripts/sync-firebase-auth-templates.sh apply
bash scripts/sync-firebase-auth-templates.sh check-remote
```

`check` on the sync script is local files only. If configure exits because no OAuth brand exists: Firebase console → Authentication → Sign-in method → Google → Enable → public-facing name **La Nonna** and a support email → Save. Confirm Project settings → General → Public-facing name. Do not create the brand with the IAP API. If apply prints `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`, file Firebase support using `scripts/firebase-auth-template-support-request.md` (verify and reset, subject and HTML). Public name plus sender still make the default subject say La Nonna while custom HTML stays locked.

**Export / invite infra in Terraform:** `firebasehosting.googleapis.com`, the worker token-creator binding, and the logging exclusion for request URLs containing `/v1/invitations/preview` or `/invite?` are in `infra/terraform`. `terraform apply` in `environments/dev` (and later prod). The exclusion is not retroactive. No schema migration for these three changes.

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
- **Retry config:** both push subscriptions use exponential backoff (`10s`–`600s`) and dead-letter after **12** attempts (`local.pubsub_max_delivery_attempts` in `pubsub.tf`). Worker env `PUBSUB_MAX_DELIVERY_ATTEMPTS` (default **12**) must match; invite email and export handlers use it to decide which Pub/Sub attempt is final.
- **Timeouts:** push subscriptions use **`ack_deadline_seconds = 300`**; worker deploy sets **`--timeout=300`**. After changing ack deadline in `pubsub.tf`, run **`terraform apply`** in the target environment (deploy alone does not update Pub/Sub).
- **FCM:** Worker SA may need **`roles/firebasecloudmessaging.admin`**

#### Dead-letter queue

Both push subscriptions dead-letter after **12** delivery attempts (with exponential backoff between tries) to topic `lanonna-async-commands-dlq`. Terraform also creates the retention subscription **`lanonna-async-commands-dlq-pull`** (7 days), a Monitoring alert when undelivered DLQ messages stay above zero for five minutes (`monitoring.tf`), and grants the Pub/Sub service agent `roles/pubsub.subscriber` on each push subscription (required for dead-lettering). Wire a notification channel in Cloud Console when ready; until then, check the DLQ after deploys and incidents:

```bash
gcloud pubsub subscriptions pull lanonna-async-commands-dlq-pull \
  --project=lanonna-dev --limit=10 --format=json          # peek; messages are redelivered unless acked
# Replay after fixing the cause: republish the decoded `data` to the original topic
gcloud pubsub topics publish lanonna-async-commands --project=lanonna-dev --message="$(…)"
```

**Infra smoke:**

```bash
export SMOKE_TEST_PASSWORD='…'
./scripts/infra-smoke-display-upload.sh
```

---

## Database migrations

Schema: **`infra/db/migrations/`** — the [migrations README](../../infra/db/migrations/README.md) lists every migration (single source for the current set).

```bash
cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5432   # or 5433
export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-lanonna-app-password --project=lanonna-dev)
cd infra/db
python3 -m venv .venv && .venv/bin/pip install 'psycopg[binary]'
DB_PASSWORD="$PGPASSWORD" DB_PORT=5432 .venv/bin/python apply_migrations.py
cd ../.. && ./scripts/verify-dev-migrations.sh   # repo root; PGPASSWORD set
```

Secrets (values in Secret Manager only): `db-lanonna-app-password`, `database-url`, `db-postgres-root-password`, `admin-api-key` (add version via `gcloud` after first apply if empty).

After migration `030` is applied, null emails on active users can be restored from Firebase Auth with `DB_PORT=5433 python infra/db/backfill_null_user_emails.py` (dry-run), then the same command with `--apply`. `--report-orphans` prints read-only counts and does not delete rows. The script needs Application Default Credentials that can call Firebase Auth `get_user`.

**Retest onboarding:** `clear_dev_test_data.py --email you@example.com --reset-onboarding` — [development.md](development.md). Powerful dev-only scripts (no project guard) are an **intentional** tradeoff — [intentional-dev-decisions.md](intentional-dev-decisions.md#m-53).

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
