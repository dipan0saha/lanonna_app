# Operations — GCP, deploy, and dev readiness

**Project:** `lanonna-dev` (Terraform state: `gs://lanonna-dev-terraform-state`). Use a Google account with deploy access to this project for Firebase CLI and Cloud Build (`gcloud auth list` / `gcloud config get-value account`).

| Topic | Doc |
|-------|-----|
| Resource inventory, console links | [infra/gcp/SETUP.md](../../infra/gcp/SETUP.md) |
| Day-to-day coding | [development.md](development.md) |
| Design principles | [platform-architecture.md](platform-architecture.md) |

---

## Dev readiness gate

Run before product feature work. Platform plumbing should be **green** first.

```bash
# Scripts default to GCP_PROJECT_ID=lanonna-dev and pass --project; never change the gcloud default project.

# Optional but recommended (Firebase test user password):
export SMOKE_TEST_PASSWORD='…'

./scripts/apply-run-iam.sh   # after worker deploy
./scripts/verify-dev-prerequisites.sh
```

| Area | Notes |
|------|--------|
| Terraform `lanonna-dev` | `terraform validate` passes; `terraform apply` when module changes — push subs (upload + async commands), **DLQ** on push, CORS, API/worker TokenCreator |
| Cloud Run `api` / `worker` | `services/*/scripts/deploy.sh` |
| Auth + API | Flutter dev or curl with Firebase JWT; `GET /health` |
| Cloud SQL | All migrations applied — proxy + `apply_migrations.py`; `./scripts/verify-migrations.sh` checks every file in `infra/db/migrations/` is recorded |
| GCS → Pub/Sub → worker | `./scripts/infra-smoke-display-upload.sh` (set `SMOKE_TEST_PASSWORD`) |
| Worker security | **No** `allUsers` on `worker`; Run invoker via `apply-run-iam.sh` |
| Quality gate | `verify-dev-prerequisites.sh` (Flutter analyze/test, API/worker compile); run `pytest` when you touch Python |
| Firebase | Local plist/json + `firebase_options.dart` (see [Flutter (dev)](#flutter-dev) below) |
| Mailjet | Secrets on worker for `send_invite_email` |
| App Check | Code ready; dev deploy defaults `APP_CHECK_ENFORCE=false` — [pre-beta-qa.md](pre-beta-qa.md). Android QA: pin `APP_CHECK_DEBUG_TOKEN` in `apps/mobile/maestro/local.env`, run `apps/mobile/maestro/scripts/register-app-check-debug.sh`, rebuild debug |
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

**Dev extras:** push subscriptions **`photo-upload-finalized-push-dev`** / **`lanonna-async-commands-push-dev`** (OIDC); push URL is read from live Cloud Run **`worker`** on `terraform apply` (override with `worker_push_endpoint` if needed). **Run invoker** for Pub/Sub is in Terraform (`run_iam.tf`); run `./scripts/apply-run-iam.sh` after worker deploy to remove **`allUsers`** and reconcile IAM if apply lacked `setIamPolicy`.

### Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk), [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.7, [Flutter](https://docs.flutter.dev/get-started/install)

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project lanonna-dev
```

Do not run `gcloud config set project`: repo scripts resolve the project from `GCP_PROJECT_ID` (default `lanonna-dev`; `lanonna-prod` for prod) via `scripts/lib/env.sh` and pass `--project` on every call. For ad-hoc commands, pass `--project=…` explicitly.

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
| Cloud SQL | `db-custom-1-3840`, 10 GB zonal, deletion protection off | `db-custom-1-3840`, 10 GB zonal, autoresize cap 20 GB, backups + 7-day PITR, deletion protection on |
| Cloud SQL HA | Zonal | Zonal (`sql_availability = REGIONAL` when ready) |
| API Cloud Run | `API_MIN_INSTANCES=1` in `dev.api.env` | `API_MIN_INSTANCES=1` in `prod.api.env` |
| Worker Cloud Run | min **0** (deploy script) | min **0** |
| GCS lifecycle rules | Off (default module) | On (abort stale multipart uploads after 1 day) |
| Platform monitoring | Off unless opted in via tfvars | On (emails + optional uptime host in tfvars) |
| Automation SA (`lanonna-automation`, Editor) | **Yes** (local only) | **No** — CI + WIF later |

**Prod launch budget (order of magnitude):** dedicated-core zonal SQL (~\$25–35/mo) + one warm API instance (~\$10–15/mo idle at 1 vCPU / 512 MiB) + small GCS/Pub/Secret/Monitoring footprint → about **\$35–60/mo** at low traffic. Shared-core tiers (e.g. `g1-small`) are cheaper but do not qualify for the [Cloud SQL SLA](https://cloud.google.com/sql/sla); prod defaults use **`db-custom-1-3840`**.

**Scale up later:** raise `sql_tier` / `sql_disk_gb` / `sql_disk_autoresize_limit`, set `sql_availability = "REGIONAL"` for HA, bump `API_MAX_INSTANCES` in `prod.api.env`, then `terraform apply` and redeploy API/worker.

### Prod (when you launch)

**Quota:** `lanonna-prod` does not exist until GCP grants a new project quota. Request quota, then run the sequence below.

1. Create **`lanonna-prod`**, link billing.
2. `./infra/terraform/scripts/ensure-state-bucket.sh lanonna-prod lanonna-prod-terraform-state`
3. `cd infra/terraform/environments/prod` → `cp terraform.tfvars.example terraform.tfvars` → set **`monitoring_notification_emails`** (gitignored tfvars; no addresses in git).
4. `terraform init && terraform apply` (fresh apply, no import). Creates Cloud SQL (small dedicated tier), Secret Manager containers, writes **`db-lanonna-app-password`** (`manage_sql_app_password = true`), enables prod bucket lifecycle rules and alert policies (uptime check waits until step 8).
5. Bootstrap remaining secrets (`mailjet-*`, `admin-api-key`, `db-postgres-root-password` as needed) via `gcloud secrets versions add`.
6. Cloud SQL Auth Proxy + `infra/db/apply_migrations.py` with `DB_PASSWORD` from **`db-lanonna-app-password`** — the full chain (currently **`001`–`052`**) on the empty DB. On a fresh database no older API is serving, so `048` and `049` are safe here; the ordering rules below apply once prod has a running API. Confirm with `./scripts/verify-migrations.sh` (`GCP_PROJECT_ID=lanonna-prod`, proxy + `PGPASSWORD`).
7. Set real values in [`infra/env/prod.worker.env`](../../infra/env/prod.worker.env) (`MAILJET_FROM_EMAIL`) and review [`infra/env/prod.api.env`](../../infra/env/prod.api.env).
8. Deploy **worker** (`GCP_PROJECT_ID=lanonna-prod`) → `./scripts/apply-run-iam.sh` → enable push subscriptions (two-phase Terraform below) → deploy **API** → set **`monitoring_api_host`** in `terraform.tfvars` from `gcloud run services describe api --format='value(status.uri)'` (hostname only) → `terraform apply` for uptime alerts → `GCP_PROJECT_ID=lanonna-prod ./scripts/setup-schedulers.sh` → invite hosting with release `ANDROID_SHA256`.
9. Confirm the schedulers: `gcloud scheduler jobs list --project=lanonna-prod --location=us-central1` must list `weekly-notification-digest`, `expire-pending-invitations`, `sweep-storage-cleanup-jobs` and **`purge-stale-event-covers`** (`0 4 * * *` UTC, added in #416), all `ENABLED`.

#### Rolling out #416 and #420 to a running prod

When prod already serves an older API, ship these PRs in this order (all commands with `GCP_PROJECT_ID=lanonna-prod`):

1. **Migration `047`** (first-moment catalog backfill, #412): apply any time; it only fills data the old and new API both read.
2. **Deploy the worker** (`./services/worker/scripts/deploy.sh`, then `./scripts/apply-run-iam.sh`). #416 moved stale event-cover purging into the worker.
3. **`./scripts/setup-schedulers.sh`** to create `purge-stale-event-covers` (it upserts, so re-running is safe). Check it with `gcloud scheduler jobs describe purge-stale-event-covers --project=lanonna-prod --location=us-central1`.
4. **Deploy the API** (`./services/api/scripts/deploy.sh`); confirm the new revision serves 100% and `/health` is ok.
5. **Migrations `048` and `049`, only after step 4.** `048` drops `app_users.email_digest_enabled`, which the old API still reads. `049` clears avatars a row does not own and adds the `*_avatar_url_owned` CHECK constraints, which the old API's writes could violate. Then run `./scripts/verify-migrations.sh` (expect `49/49`).

Users whose stored avatar was an external link (for example an OAuth provider photo) see initials after `049` until they pick a photo again.

**Legacy `database-url` secret:** removed from the module in `e25c3fd` and intentionally deleted from `lanonna-dev` by the next apply. Cloud Run uses `DB_*` + `db-lanonna-app-password`; do not recreate it.

Real users on prod = **new Firebase project + prod flavor**, not renaming dev. See [platform-architecture.md](platform-architecture.md).

#### Prod Terraform: two-phase apply (push subscriptions)

Prod [`environments/prod/main.tf`](../../infra/terraform/environments/prod/main.tf) ships with **`enable_worker_push_subscription = false`** until Cloud Run **`worker`** exists. Match [`terraform.tfvars.example`](../../infra/terraform/environments/prod/terraform.tfvars.example):

**Phase 1 — platform without push subs:** `terraform apply` after creating `terraform.tfvars` (APIs, SQL, secrets, buckets, topics, Run service accounts, FCM IAM, etc.). Deploy the worker image to prod.

**Phase 2 — push subs:** In `module "platform"` set `enable_worker_push_subscription = true`, subscription names (e.g. `photo-upload-finalized-push-prod`, `lanonna-async-commands-push-prod`), leave `worker_push_endpoint` empty to read the live worker URL, then `terraform apply` again.

Run `./scripts/apply-run-iam.sh` with `GCP_PROJECT_ID=lanonna-prod` after each worker deploy (same as dev).

### Project and environment (deploy scripts)

[`scripts/lib/env.sh`](../../scripts/lib/env.sh) resolves **`GCP_PROJECT_ID`** (default **`lanonna-dev`**) and **`ENVIRONMENT`** (`lanonna-dev` → `dev`, `lanonna-prod` → `prod`). It fails closed: any other project id is an error, `ENVIRONMENT=prod` without `GCP_PROJECT_ID=lanonna-prod` is an error (never a dev fallback), and a pre-set `ENVIRONMENT` that disagrees with the project is an error. Sourcing it turns on `set -euo pipefail`. API and worker deploy scripts load **`infra/env/<environment>.api.env`** / **`.worker.env`** unless `API_ENV_FILE` / `WORKER_ENV_FILE` overrides.

| File | Purpose |
|------|---------|
| [`infra/env/dev.api.env`](../../infra/env/dev.api.env) | Dev API min/max instances (warm instance) |
| [`infra/env/dev.worker.env`](../../infra/env/dev.worker.env) | Dev Mailjet sender (non-secret) |
| [`infra/env/prod.api.env`](../../infra/env/prod.api.env) | Prod API scaling + `APP_CHECK_ENFORCE` |
| [`infra/env/prod.worker.env`](../../infra/env/prod.worker.env) | Prod Mailjet sender — **must** replace `__SET_PROD_MAILJET_FROM_EMAIL__` before first deploy |

---

## Application deploy (dev)

| Service | Cloud Run name | Deploy |
|---------|----------------|--------|
| **API** | `api` | `./services/api/scripts/deploy.sh` |
| **Worker** | `worker` | `./services/worker/scripts/deploy.sh` then **`./scripts/apply-run-iam.sh`** |

Scripts use **Cloud Build** → `us-central1-docker.pkg.dev/lanonna-dev/lanonna/…`. Optional: `USE_LOCAL_DOCKER=1`.

**Build context (M-48):** `gcloud builds submit` uses the **repo root** as source. Root [`.gcloudignore`](../../.gcloudignore) whitelists only `packages/` and `services/` (plus secret/cache exclusions); root [`.dockerignore`](../../.dockerignore) matches for local Docker. To inspect what would upload: `gcloud meta list-files-for-upload .` from the repo root. If a Dockerfile starts `COPY`ing paths outside those trees, extend both ignore files.

**API scaling (per environment):** `services/api/scripts/deploy.sh` reads non-secret Cloud Run settings from `infra/env/<env>.api.env` (parsed, not executed, via `scripts/lib/env_file.sh`; shell wins). Dev sets `API_MIN_INSTANCES=1` so one instance stays warm: a scale-from-zero first request took about 9–10 s (container start), warm requests about 0.05–0.15 s. Idle cost is about $10/month at 1 vCPU / 512 MiB (request-based billing, CPU throttled when idle). Without an env file the defaults are min 0 / max 10. Prod [`prod.api.env`](../../infra/env/prod.api.env) mirrors dev warm-instance policy and sets `APP_CHECK_ENFORCE=true`. The worker stays at min 0 (Pub/Sub push retries absorb its cold start). To change dev without a rebuild: `gcloud run services update api --region=us-central1 --min-instances=N`, and update `dev.api.env` so the next deploy keeps it.

**API deploy wires:** Cloud SQL `lanonna-dev:us-central1:lanonna-db`, secret `db-lanonna-app-password` → `DB_PASSWORD`, `DISPLAY_BUCKET=lanonna-dev-display`, `GCS_SIGNING_SERVICE_ACCOUNT=lanonna-api@lanonna-dev.iam.gserviceaccount.com`.

**GCS signed uploads:** `lanonna-api` needs `roles/iam.serviceAccountTokenCreator` on itself (`run_iam.tf` → `api_self_token_creator`).

**Cloud Build IAM:** If deploy fails, grant default compute / Cloud Build SAs `cloudbuild.builds.builder`, `storage.admin`, `artifactregistry.writer`, `logging.logWriter`, and `run.admin` + `iam.serviceAccountUser` on the Cloud Build SA.

**Deploy order when both change:** apply **migrations** first if needed → **worker** → `apply-run-iam.sh` → **API**. Email templates: `bash scripts/sync-email-templates.sh apply` before worker deploy when templates changed.

**Worker sender (#43):** `MAILJET_FROM_EMAIL` is configuration, not a Secret Manager value. `services/worker/scripts/deploy.sh` resolves it with precedence exported shell variable > gitignored **`infra/env/<env>.worker.local.env`** (copy from `dev.worker.local.env.example` on dev) > `infra/env/<env>.worker.env`; the tracked file's other settings (e.g. `MAILJET_FROM_NAME`) always load. Worker and API deploys pass `--project` and never change the gcloud default project. Deploy **fails fast** if the sender is missing. Prod committed values use placeholders like `__SET_PROD_MAILJET_FROM_EMAIL__` that deploy rejects. Values with spaces are quoted. Deploy and worker startup refuse an empty sender and `hello@lanonna.app` (Mailjet returns HTTP 200 for that address and drops the message). A Mailjet HTTP 200 whose `Messages[0].Status` is not `success` is a send failure: the invite claim is released and `email_sent_at` is not set.

**Worker invite link and export signing:** `deploy.sh` sets `INVITE_DEEP_LINK_BASE=https://${project_id}.firebaseapp.com` and `GCS_SIGNING_SERVICE_ACCOUNT=lanonna-worker@${project_id}.iam.gserviceaccount.com`. Export media URLs need `lanonna-worker` to be `roles/iam.serviceAccountTokenCreator` on itself (`run_iam.tf` `worker_self_token_creator`, also granted by `./scripts/apply-run-iam.sh`). Startup rejects an invite base that is not `https://`, and rejects a `lanonna-dev` host when `ENVIRONMENT` is not `dev`.

**Invite landing (Firebase Hosting):** from the repo root, after the API is deployed (`--allow-unauthenticated`):

```bash
# Dev: omit ANDROID_SHA256 to read ~/.android/debug.keystore (alias androiddebugkey).
# Prod (GCP_PROJECT_ID=lanonna-prod): ANDROID_SHA256 is required (release/upload keystore).
# APPLE_TEAM_ID is optional; without it iOS stays on the web fallback.
ANDROID_SHA256='AA:BB:…' APPLE_TEAM_ID='XXXXXXXXXX' \
  bash scripts/deploy-invite-hosting.sh
```

The script uses [`scripts/lib/env.sh`](../../scripts/lib/env.sh) for project/environment, enables `firebasehosting.googleapis.com`, renders per-environment `assetlinks.json` and `apple-app-site-association`, and runs `firebase deploy --only hosting` from `hosting/` ([`hosting/.firebaserc`](../../hosting/.firebaserc) aliases `dev` / `prod`). The `/v1/invitations/preview` rewrite targets Cloud Run **`api`**, which must stay **publicly invokable** at the Run layer (`--allow-unauthenticated` on deploy); Firebase Hosting does not use a separate invoker binding in this project ([rca/repo-email-scrub-and-hosting-iam.md](rca/repo-email-scrub-and-hosting-iam.md)). `hosting/firebase.json` must not ignore `**/.*`: that default drops `.well-known`, so Android App Links and the Apple association file would never be published. Re-run is safe. Play Store `https://play.google.com/store/apps/details?id=com.lanonna.lanonna` may 404 until the listing exists; the page says to ask the inviter. After install, the person opens the **same email link** again (no install referrer). Prod: point the Android manifest host, iOS entitlements, and `INVITE_DEEP_LINK_BASE` at the prod `firebaseapp.com` host.

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
- Schedulers (weekly digest + expired invites): `./scripts/setup-schedulers.sh` (idempotent; not in Terraform)
- **Push auth:** OIDC; Run invoker via `apply-run-iam.sh` after each worker deploy
- **Retry config:** both push subscriptions use exponential backoff (`10s`–`600s`) and dead-letter after **12** attempts (`local.pubsub_max_delivery_attempts` in `pubsub.tf`). Worker env `PUBSUB_MAX_DELIVERY_ATTEMPTS` (default **12**) must match; invite email and export handlers use it to decide which Pub/Sub attempt is final.
- **Timeouts:** push subscriptions use **`ack_deadline_seconds = 300`**; worker deploy sets **`--timeout=300`**. After changing ack deadline in `pubsub.tf`, run **`terraform apply`** in the target environment (deploy alone does not update Pub/Sub).
- **FCM:** Terraform grants **`roles/firebasecloudmessaging.admin`** to `lanonna-worker` (`iam.tf`). On **dev**, import the existing binding once so apply does not churn:

```bash
cd infra/terraform/environments/dev
terraform import \
  'module.platform.google_project_iam_member.worker_firebase_cloud_messaging_admin' \
  'lanonna-dev roles/firebasecloudmessaging.admin serviceAccount:lanonna-worker@lanonna-dev.iam.gserviceaccount.com'
```

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
# FIREBASE_API_KEY is optional: defaults from apps/mobile/lib/firebase/firebase_options_dev.dart
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
cd ../.. && ./scripts/verify-migrations.sh   # repo root; PGPASSWORD set
```

Secrets (values in Secret Manager only): `db-lanonna-app-password`, `db-postgres-root-password`, `admin-api-key` (add version via `gcloud` after first apply if empty).

After migration `030` is applied, null emails on active users can be restored from Firebase Auth with `DB_PORT=5433 python infra/db/backfill_null_user_emails.py` (dry-run), then the same command with `--apply`. `--report-orphans` prints read-only counts and does not delete rows. The script needs Application Default Credentials that can call Firebase Auth `get_user`.

**Retest onboarding:** `clear_dev_test_data.py --email you@example.com --reset-onboarding` — [development.md](development.md). Powerful dev-only scripts (no project guard) are an **intentional** tradeoff — [intentional-dev-decisions.md](intentional-dev-decisions.md#m-53).

---

## Flutter (dev)

- Package: `com.lanonna.lanonna`; Firebase **`lanonna-dev`**
- Gitignored: `google-services.json`, `GoogleService-Info.plist`
- Checked in: `lib/firebase/firebase_options_dev.dart` (prod placeholder in `firebase_options_prod.dart` until `flutterfire configure`)
- Flavor: `apps/mobile/flavors/dev.json` — **`API_BASE_URL`**, `APP_LINK_HOST`, `APP_ENV=dev`
- Prod template: `flavors/prod.json` — see [mobile-prod-flavor-and-crashlytics.md](mobile-prod-flavor-and-crashlytics.md)
- Release signing: dev release always uses the debug keystore; `android/key.properties` (gitignored) is required only for **prod** release ([android/README.md](../../apps/mobile/android/README.md), [rca/release-signing-environment.md](rca/release-signing-environment.md))
- Crashlytics: enabled for prod; dev release on by default (`CRASHLYTICS_ENABLED` in flavor JSON to opt out)

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json
```

**Dev release APK (unchanged):**

```bash
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=flavors/dev.json
```

**Prod release (after owner fills `flavors/prod.json`, keystore, and `flutterfire configure`):**

```bash
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=flavors/prod.json
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
# Pass --project=lanonna-dev (or GCP_PROJECT_ID) instead of changing the gcloud default project.
```

Switch back for interactive work: `gcloud config set account YOUR_HUMAN_GOOGLE_ACCOUNT` (the email you use for `gcloud auth login`).

---

## Manual checklist

| Item | Action |
|------|--------|
| Firebase Blaze | Done on `lanonna-dev` |
| Email/Password Auth | Enabled; smoke user via `SMOKE_TEST_PASSWORD` |
| Billing budgets | $50 / $150 / $300 on dev |
| Mailjet secrets | Set in Secret Manager — rotate if exposed |
| App Check | Register Android debug token(s) for QA (`register-app-check-debug.sh` or Console); enforce on API before wide beta (`APP_CHECK_ENFORCE=true` deploy) |
| Google / Apple sign-in | Enable in Firebase when product-ready |

---

## Security

- No SA JSON, `terraform.tfvars` secrets, or Firebase plist/json in git.
- Dev worker: **OIDC push**, no `allUsers`; re-run `apply-run-iam.sh` after worker deploy.
- Terraform creates Secret Manager **IDs** only; values via `gcloud` / console.

---

## Console links (`lanonna-dev`)

- [GCP project](https://console.cloud.google.com/home/dashboard?project=lanonna-dev)
- [Firebase](https://console.firebase.google.com/project/lanonna-dev/overview)
- [Cloud SQL](https://console.cloud.google.com/sql/instances/lanonna-db?project=lanonna-dev)
- [Cloud Run](https://console.cloud.google.com/run?project=lanonna-dev)
- [Cloud Build](https://console.cloud.google.com/cloud-build/builds?project=lanonna-dev)
- [Secret Manager](https://console.cloud.google.com/security/secret-manager?project=lanonna-dev)
