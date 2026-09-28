# GCP setup — La Nonna (`lanonna-dev`)

This documents what was provisioned for Path B and what you still do manually.

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
| Pub/Sub subscription | `photo-upload-finalized-worker` |
| GCS notification | `lanonna-dev-display` → topic (OBJECT_FINALIZE) |
| Artifact Registry (Docker) | `us-central1-docker.pkg.dev/lanonna-dev/lanonna` |
| Secret Manager | `database-url`, `db-lanonna-app-password`, `db-postgres-root-password`, `mailjet-api-key`, `mailjet-api-secret` |

## Service accounts

| Account | Purpose |
|---------|---------|
| `lanonna-automation@lanonna-dev.iam.gserviceaccount.com` | **Cursor / automation** — Editor + IAM admin on project (dev only) |
| `lanonna-api@lanonna-dev.iam.gserviceaccount.com` | Cloud Run **api** runtime |
| `lanonna-worker@lanonna-dev.iam.gserviceaccount.com` | Cloud Run **worker** runtime |

### Automation key (local only)

JSON key path (not in git):

```text
~/Neo_Workspace/secrets/lanonna/gcp-automation-key.json
```

Use for agents and scripts:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/Neo_Workspace/secrets/lanonna/gcp-automation-key.json"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
gcloud config set project lanonna-dev
```

**Security:** Do not commit the key. Rotate in IAM if leaked. Narrow roles before production.

## Manual steps (you)

1. **Firebase Blaze** — [Usage & billing](https://console.firebase.google.com/project/lanonna-dev/usage/details) → upgrade (required for Cloud SQL connect / production Firebase features).
2. **Firebase Auth** — Enable Email/Password (+ Google / Apple when ready) in console.
3. **FCM, Crashlytics, Analytics, Remote Config, App Check** — enable in Firebase console as you build.
4. **Mailjet** — Replace `REPLACE_ME` in Secret Manager secrets `mailjet-api-key` / `mailjet-api-secret`.
5. **Flutter** — Register iOS/Android apps in Firebase; download `google-services.json` / `GoogleService-Info.plist` into `apps/mobile` (gitignored).
6. **Firebase CLI login** — Use an account with access to `lanonna-dev` (`firebase login`); if you use `lanonnaapp@gmail.com` for GCP, prefer that account for Firebase CLI too.

## Infrastructure as code

Platform resources are managed with **Terraform** — see [docs/initial-setup.md](../../docs/initial-setup.md).

Legacy `bootstrap.sh` is deprecated.

## Cloud SQL access from laptop

```bash
cloud-sql-proxy lanonna-dev:us-central1:lanonna-db
# DATABASE_URL is in Secret Manager secret `database-url`
gcloud secrets versions access latest --secret=database-url --project=lanonna-dev
```

## Console links

- [GCP project](https://console.cloud.google.com/home/dashboard?project=lanonna-dev)
- [Cloud SQL](https://console.cloud.google.com/sql/instances/lanonna-db?project=lanonna-dev)
- [Cloud Run](https://console.cloud.google.com/run?project=lanonna-dev)
- [Secret Manager](https://console.cloud.google.com/security/secret-manager?project=lanonna-dev)
- [Billing](https://console.cloud.google.com/billing/018CE3-2C7894-996502)
