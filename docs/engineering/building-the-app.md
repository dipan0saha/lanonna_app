# Building the main app — prerequisite gate

Use this before product feature work (families, babies, feed, uploads in Flutter). Platform plumbing should be **green** first.

## Quick verify

```bash
gcloud config set account lanonnaapp@gmail.com
gcloud config set project lanonna-dev

# Optional but recommended (Firebase test user password):
export SMOKE_TEST_PASSWORD='…'

./scripts/apply-dev-run-iam.sh   # after worker deploy
./scripts/verify-dev-prerequisites.sh
```

## Checklist (what “ready” means)

| Area | Status | Notes |
|------|--------|--------|
| Terraform `lanonna-dev` | `terraform validate` passes; apply when module changes | Push sub, CORS, API/worker TokenCreator in `modules/platform` |
| Cloud Run `api` / `worker` | Deployed | `services/*/scripts/deploy.sh` |
| Auth + API | Smoke-tested | Flutter dev screen or curl with Firebase JWT |
| Cloud SQL | `001` + `002_core_domain.sql` applied | Proxy + `psql` — [initial-setup.md](initial-setup.md) |
| GCS → Pub/Sub → worker | `./scripts/infra-smoke-display-upload.sh` | Signed PUT + worker `gcs_object_finalized` log |
| Worker security (dev) | **No** `allUsers` on `worker` | Push sub + OIDC in Terraform; **Run invoker** via `apply-dev-run-iam.sh` |
| CI | Green on `main` | Flutter + API compile in GitHub Actions |
| Firebase config | Local plist/json + `firebase_options.dart` | [initial-setup.md](initial-setup.md) |
| Mailjet | Secrets set | App code not required until invites |
| App Check / FCM | **Not required yet** | Add when hardening or push notifications |

## What you build next (product)

Follow [platform-architecture.md](platform-architecture.md) Month 1–2:

1. SQL migrations: `002_core_domain.sql` (apply on dev) + expand domain tables as features land
2. Flutter display encode + `POST /v1/photos/init` (smoke path: `POST /v1/uploads/display/signed-url`)
3. Worker: thumbnail from `display/{photo_id}.*` (idempotent; deploy worker after API)
4. **In progress:** app shell (5 tabs, PRD theme, auth) — wire home sections + gallery upload next

## If worker URL changes

After redeploying worker, update Terraform and apply:

```hcl
# infra/terraform/environments/dev/main.tf
worker_push_endpoint = "https://worker-….us-central1.run.app/pubsub/push"
```

```bash
cd infra/terraform/environments/dev && terraform apply
```

## Related

- [product/requirements.md](../product/requirements.md) — product scope and FR/NFR IDs
- [initial-setup.md](initial-setup.md) — GCP, deploy, secrets
- [development.md](development.md) — repo layout
