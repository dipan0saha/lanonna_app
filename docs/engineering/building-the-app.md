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
| Cloud SQL | Migrations through **`022`** applied on dev | Proxy + `apply_migrations.py`; retest cleanup: `clear_dev_test_data.py` — [migrations/README.md](../../infra/db/migrations/README.md) |
| GCS → Pub/Sub → worker | `./scripts/infra-smoke-display-upload.sh` | Signed PUT + worker `gcs_object_finalized` log |
| Worker security (dev) | **No** `allUsers` on `worker` | Push sub + OIDC in Terraform; **Run invoker** via `apply-dev-run-iam.sh` |
| CI | Green on `main` | `flutter analyze` + `flutter test`; API + worker `pytest` — see [development.md](development.md) |
| Firebase config | Local plist/json + `firebase_options.dart` | [initial-setup.md](initial-setup.md) |
| Mailjet | Secrets set on worker | Invite emails via worker `send_invite_email` (batch invite from onboarding or home) |
| App Check | **Code ready** — deploy API with `APP_CHECK_ENFORCE=true`; register debug tokens | [pre-beta-qa.md](pre-beta-qa.md), [initial-setup.md](initial-setup.md) |
| FCM push | **Deployed on dev** | Migration `014`, worker `firebase-admin`, mobile `PushNotificationService`; iOS Push capability in Xcode |

## What you build next (product)

Follow [platform-architecture.md](platform-architecture.md) Month 1–2:

1. SQL migrations: keep dev current per [migrations/README.md](../../infra/db/migrations/README.md) (through `022`)
2. **Done:** **Gallery** + **Calendar** — social API (`007`), Flutter tabs, signed read URLs, squish/RSVP/comments; worker `photo_shared` on thumb ready
3. **Done:** **Registry** + **Fun** — social API (`008`), Flutter tabs, purchase/votes/likes; static AI suggestion JSON (calendar + registry)
4. **Done:** app shell + **owner onboarding** (carousel → auth → profile → baby → first moment → invites → home)
5. **Done (owner home):** modular home UI, announce arrival (PATCH), `/invite-family`, `GET …/home-summary` + `activity_events` (API + gallery/calendar/registry/fun mutations where applicable)
6. **Done:** follower home (`home-summary` for members, `FollowerHomeComposer`); owner storage meter on My Account only (`GET /v1/me/account`, not home-summary)
7. **Done (account):** notification prefs + inbox UI, global search, baby data export, account delete
8. **Done (notifications):** Pub/Sub notify writers (photo ready, squish, comment, event, RSVP, registry claim, baby arrived, invite accepted); FCM for `notification_digest=realtime`; weekly digest push via `./scripts/setup-weekly-digest-scheduler.sh` (Pub/Sub on worker topic)
9. **Done (home §6.2):** PRD home sections via extended `home-summary`, `/calendar/upcoming`, `/home/activity`, migration `015` + admin system announcements API
10. **Done (pre-beta gate):** display encode (`core/media/display_encode.dart`), disk cache (`CachedSignedImage`), App Check (Flutter + API), QA runbook — complete [pre-beta-qa.md](pre-beta-qa.md) on device before wide beta
11. **Done (invites):** cold/warm `lanonna://app/invite-accept` via `app_links` — QA per [development.md](development.md) invite section
12. **Done (settings polish):** `/settings`, per-channel notification prefs (migration `016`), Help mailto (`SUPPORT_EMAIL`), l10n pilot (`app_en.arb`); sync dev API URL via [flavors/README.md](../../apps/mobile/flavors/README.md)
13. **Done (gallery gaps):** comment edit (FR-GAL-007 PATCH + UI), photo baby tags v1 (FR-GAL-008, migration `019`), `resolveSelectedBaby` on upcoming/export/batch invite, gallery `home-summary` error banner, signed-URL image retry — redeploy API after schema/API changes (`services/api/scripts/deploy.sh`)
14. **Done (gallery refresh):** `GalleryRepository` + `notifyGalleryDataChanged` + `BabyContextReload` — gallery grid, sub-routes, and home photo teasers refresh after upload/delete/squish/comment without manual pull-to-refresh (FR-GAL-013)
15. **Done (unified create baby):** `CreateBabyScreen` — onboarding + `/baby/create` share one form/submit pipeline (`CreateBabyMode`)
16. **Done (#410 account surfaces):** `AppBorderedSurface` + `subpageScrollPadding` — My Account and home owner/teaser tiles align to 26px content width; `CardTheme` horizontal margin removed
16. **Release APK to Drive:** `./scripts/ship_release_apk_to_drive.sh` (dev flavor; universal APK → `lanonna_app.apk`). **Emulator (x86_64):** `./scripts/ship_release_apk_x86_64_to_drive.sh` → `lanonna_app_x86_64.apk` (smaller, one ABI).
17. **Beta gate:** `./scripts/run-beta-gate.sh` (tests + optional API deploy); `./scripts/setup-expired-invites-scheduler.sh`; force-update via `app_versions` + `GET /v1/app/version` (Flutter `AppVersionGate`)

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
- [performance.md](performance.md) — measurement and performance improvement backlog
