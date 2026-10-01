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
| Cloud SQL | Migrations `001`–`010` applied on dev | Proxy + `apply_migrations.py`; retest cleanup: `clear_dev_test_data.py` — [migrations/README.md](../../infra/db/migrations/README.md) |
| GCS → Pub/Sub → worker | `./scripts/infra-smoke-display-upload.sh` | Signed PUT + worker `gcs_object_finalized` log |
| Worker security (dev) | **No** `allUsers` on `worker` | Push sub + OIDC in Terraform; **Run invoker** via `apply-dev-run-iam.sh` |
| CI | Green on `main` | `flutter analyze` + `flutter test`; API `pytest`; worker `compileall` — see [development.md](development.md) |
| Firebase config | Local plist/json + `firebase_options.dart` | [initial-setup.md](initial-setup.md) |
| Mailjet | Secrets set on worker | Invite emails via worker `send_invite_email` (batch invite from onboarding or home) |
| App Check / FCM | **Not required yet** | Add when hardening or push notifications |

## What you build next (product)

Follow [platform-architecture.md](platform-architecture.md) Month 1–2:

1. SQL migrations: keep dev on `001`–`010` ([migrations/README.md](../../infra/db/migrations/README.md))
2. **Done:** **Gallery** + **Calendar** — social API (`007`), Flutter tabs, signed read URLs, squish/RSVP/comments; worker `photo_shared` on thumb ready
3. **Done:** **Registry** + **Fun** — social API (`008`), Flutter tabs, purchase/votes/likes; static AI suggestion JSON (calendar + registry)
4. **Done:** app shell + **owner onboarding** (carousel → auth → profile → baby → first moment → invites → home)
5. **Done (owner home):** modular home UI, announce arrival (PATCH), `/invite-family`, `GET …/home-summary` + `activity_events` (API + gallery/calendar/registry/fun mutations where applicable)
6. **Done:** follower home (`home-summary` for members, `FollowerHomeComposer`), account engagement stats + storage on `GET /v1/me/account`
7. **Next:** FCM notifications, App Check on API, notification preferences UI

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
