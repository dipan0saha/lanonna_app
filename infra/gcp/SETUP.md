# GCP setup — La Nonna (`lanonna-dev`)

Resource inventory for Path B. **Deploy, endpoints, smoke tests, and runbooks:** [docs/engineering/initial-setup.md](../../docs/engineering/initial-setup.md).

## Project

| Item | Value |
|------|--------|
| **GCP project ID** | `lanonna-dev` |
| **Region** | `us-central1` |
| **Billing** | Linked to trial / My Billing Account |
| **Firebase** | Enabled on same project ([console](https://console.firebase.google.com/project/lanonna-dev/overview)) |

## Provisioned resources

| Resource | Name / ID |
|----------|-----------|
| Cloud SQL (Postgres 16, zonal, `db-custom-1-3840`) | `lanonna-db` |
| Database | `lanonna` |
| DB user | `lanonna_app` |
| GCS display bucket | `gs://lanonna-dev-display` |
| GCS thumbnails bucket | `gs://lanonna-dev-thumbnails` |
| Pub/Sub topic | `photo-upload-finalized` |
| Pub/Sub subscription (Terraform, pull) | `photo-upload-finalized-worker` |
| Pub/Sub subscription (dev push → worker) | `photo-upload-finalized-push-dev` |
| GCS notification | `lanonna-dev-display` → topic (`OBJECT_FINALIZE`) |
| Artifact Registry (Docker) | `us-central1-docker.pkg.dev/lanonna-dev/lanonna` |
| Cloud Run | `api`, `worker` |
| Secret Manager | `database-url`, `db-lanonna-app-password`, `db-postgres-root-password`, `mailjet-api-key`, `mailjet-api-secret` |

## Service accounts

| Account | Purpose |
|---------|---------|
| `lanonna-automation@lanonna-dev.iam.gserviceaccount.com` | **Automation** — Editor (dev only) |
| `lanonna-api@lanonna-dev.iam.gserviceaccount.com` | Cloud Run **api** (SQL, secrets, GCS signed URLs) |
| `lanonna-worker@lanonna-dev.iam.gserviceaccount.com` | Cloud Run **worker** |

`lanonna-api` has **self** `roles/iam.serviceAccountTokenCreator` on dev for V4 signed URLs (manual IAM; codify in Terraform later).

`lanonna-api` needs **`roles/firebaseauth.admin`** so `POST /v1/me/delete-account` can remove the Firebase user (Terraform: `api_firebase_auth_admin` in `modules/platform/iam.tf`).

### Automation key (local only)

```text
~/Neo_Workspace/secrets/lanonna/gcp-automation-key.json
```

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/Neo_Workspace/secrets/lanonna/gcp-automation-key.json"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
gcloud config set project lanonna-dev
```

Prefer **`lanonnaapp@gmail.com`** for Cloud Build / `deploy.sh` (automation SA often cannot upload to Cloud Build).

## Manual / ongoing (summary)

| Item | Notes |
|------|--------|
| Firebase Blaze, Email/Password Auth | Done on `lanonna-dev` |
| Billing budgets ($50 / $150 / $300) | Created |
| Mailjet | Secret versions set — rotate if keys were ever exposed |
| Flutter plist/json | Local under `apps/mobile` (gitignored); apps registered in Firebase |
| FCM, App Check, Google/Apple sign-in | When you build those features |

## Infrastructure as code

**Terraform:** `infra/terraform/` — see [initial-setup.md](../../docs/engineering/initial-setup.md). Legacy `bootstrap.sh` is deprecated.

## Cloud SQL access from laptop

```bash
cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5432
export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-lanonna-app-password --project=lanonna-dev)
psql -h 127.0.0.1 -U lanonna_app -d lanonna
```

## Console links

- [GCP project](https://console.cloud.google.com/home/dashboard?project=lanonna-dev)
- [Firebase](https://console.firebase.google.com/project/lanonna-dev/overview)
- [Cloud SQL](https://console.cloud.google.com/sql/instances/lanonna-db?project=lanonna-dev)
- [Cloud Run](https://console.cloud.google.com/run?project=lanonna-dev)
- [Cloud Build](https://console.cloud.google.com/cloud-build/builds?project=lanonna-dev)
- [Secret Manager](https://console.cloud.google.com/security/secret-manager?project=lanonna-dev)
- [Billing](https://console.cloud.google.com/billing/018CE3-2C7894-996502)
