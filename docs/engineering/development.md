# Development guide

## Repository layout

```
lanonna_app/
├── apps/
│   └── mobile/              # Flutter client (Firebase Auth, API client, display encode)
├── services/
│   ├── api/                 # Cloud Run HTTP API (JWT, CRUD, signed GCS URLs)
│   └── worker/              # Cloud Run Pub/Sub worker (thumbs, email, FCM)
├── scripts/                 # verify-dev-prerequisites.sh, infra smoke, Run IAM
├── packages/
│   └── email-templates/     # Mailjet HTML/text templates (versioned)
├── infra/
│   ├── db/                  # `apply_migrations.py`, `clear_dev_test_data.py`, migrations/
│   ├── terraform/           # GCP platform (dev/prod)
│   └── gcp/                 # Resource inventory (SETUP.md)
├── docs/                    # product/ + engineering/ documentation
└── .github/workflows/       # CI: Flutter analyze/test, API pytest, worker compileall
```

**Deploy model:** `api` and `worker` ship as **two Cloud Run services** — see [platform-architecture.md](platform-architecture.md).

**Before main product work:** [building-the-app.md](building-the-app.md) and `./scripts/verify-dev-prerequisites.sh`.

### Mobile feature modules (`apps/mobile/lib/features/`)

| Module | Shell route | Notes |
|--------|-------------|--------|
| `home/` | `/home` | Owner expecting/born; `home-summary`; announce arrival |
| `gallery/` | `/gallery`, `/gallery/recent`, `/gallery/favorites` | Grid (`sort` via API), detail, squish, comments (create/edit/delete), owner baby tags (“In this photo”); `/gallery/photo/:id`; owner all-mode shows `home-summary` activity with retry banner on failure |
| `calendar/` | `/calendar` | Month + upcoming; event CRUD; static AI suggestions (`AiSuggestionsScaffold` + asset) |
| `registry/` | `/registry` | Needed/purchased, shipping, purchase claim; AI suggestions |
| `fun/` | `/gamification` | Names + Predictions tabs (**Family Fun**) |
| `account/` | `/profile`, `/account/edit`, `/baby/create`, `/baby/:id/edit`, `/baby/:id/followers` | Profile card, baby list, add/edit baby |
| `announcement/` | `/baby/:id/announcement`, `/baby/:id/announcement/create` | Keepsake card (signed `photo_display_url` on GET) + create |
| `shell/` | (sheet from tab `HomeTopBar`) | Baby switcher; **My Account** footer |
| `onboarding/`, `invitations/` | Onboarding + deep links | Owner/follower/co-owner paths |

Repositories are registered in `bootstrap.dart`; routes in `core/router/app_router.dart`. Legacy redirects: `/login` → onboarding login, `/role-selection` → owner carousel. Shared API models (e.g. `BabySummary`) live under `apps/mobile/lib/core/domain/`. **Selected baby:** `HomeRepository.resolveSelectedBaby(SelectedBabyStore)` — use for baby-scoped loads (not raw `selectedBabyId` alone). **Route-scoped baby:** `HomeRepository.babyById(id)` for deep links and screens keyed by `babyId` in the URL. Static catalogs: `assets/calendar/event_suggestions.json`, `assets/registry/registry_suggestions.json`.

### API layout (`services/api/src/lanonna_api/`)

| Layer | Role |
|-------|------|
| `routers/` | HTTP handlers (`photos`, `events`, `registry`, `fun`, `babies`, …) |
| `domain/` | Membership, permissions, activity + notify hooks (`gallery`, `calendar`, `registry`, `fun`, `home`, `notifications`, `invitations`, `onboarding`, `membership`, `name_suggestions`) |
| `repositories/` | Parameterized SQL only |
| `storage.py` | V4 signed PUT (upload) and GET (thumb/display read) |

## Prerequisites

- Flutter SDK (see `apps/mobile`)
- GCP `lanonna-dev` on Blaze, `us-central1` — [initial-setup.md](initial-setup.md)
- Docker optional (deploy uses Cloud Build)

## Mobile app

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json
```

`google-services.json` / `GoogleService-Info.plist` are local (gitignored). Dev flavor: `apps/mobile/flavors/dev.json`. iOS: minimum **15.0**, run `cd ios && pod install` once.

### Text input capitalization

User-facing text fields should use [`AppTextField`](../../apps/mobile/lib/core/widgets/app_text_field.dart) (or [`OnboardingTextField`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_fields.dart) with `AppTextInputKind`) instead of raw `TextField` + `TextCapitalization`. Policy lives in [`app_text_input_kind.dart`](../../apps/mobile/lib/core/input/app_text_input_kind.dart): `personName` (title-case per word), `prose` (sentence-case), `none` (email, password, URLs, search). On submit, call `AppTextInputPolicy.normalizeForSubmit(kind, text)` before persisting to the API.

### Automated tests

| Layer | Command | CI (`main`) |
|-------|---------|-------------|
| Mobile unit/widget | `cd apps/mobile && flutter test` | Yes |
| Mobile integration | `flutter test integration_test/home_summary_load_test.dart` (device/emulator) | No — run locally before release |
| Maestro (Android) | `./maestro/scripts/run-maestro-smoke.sh` after proxy + deploy | No — see [maestro/README.md](../../apps/mobile/maestro/README.md) |
| API | `PYTHONPATH=services/api/src services/api/.venv/bin/pytest -q services/api/tests` | Yes |

**Signed read URLs** expire after **900s** ([`storage.py`](../../services/api/src/lanonna_api/storage.py)). `CachedSignedImage` accepts optional `onSignedUrlError` (one callback per widget mount) so parents can refresh API data (home teasers, photo detail).

### Maestro E2E (Android)

Black-box UI tests under `apps/mobile/maestro/`. Use semantics ids (`nav_home`, `auth_sign_in`, …) via `AppSemantics` in `lib/core/widgets/app_semantics.dart`. Copy `maestro/local.env.example` → `maestro/local.env` with the dev smoke password (`lanonna.dev.smoke@test.com`). Start Cloud SQL Auth Proxy (port **5433** recommended when **5432** is in use; set `DB_PORT` consistently). Scripts:

| Script | Scope |
|--------|--------|
| `./maestro/scripts/run-maestro.sh` | **Smoke** (default): provision smoke user, build/install, App Check prep, four `flows/smoke/*` flows |
| `./maestro/scripts/run-maestro-smoke.sh` | Same as above (explicit) |
| `./maestro/scripts/run-maestro-full.sh` | Smoke + feature + follower + invite deep link + fresh onboarding (final gate) |

See [maestro/README.md](../../apps/mobile/maestro/README.md).

### Theming (single source of truth)

Product UI tokens live under `apps/mobile/lib/core/theme/` (see also PRD §5.1):

| File | Role |
|------|------|
| `app_colors.dart` | Raw brand hex (palette only) |
| `app_metrics.dart` | Spacing, radii, button sizes |
| `app_text_theme.dart` | Inter + Baloo 2 text styles |
| `app_brand_theme.dart` | `ThemeExtension` — sage/peach tints, insight fills |
| `app_theme.dart` | `AppTheme.light` → `ThemeData` + component themes |
| `la_nonna_theme.dart` | `context.textStyles`, `context.brand`, `context.colors` |
| `theme.dart` | Barrel export for feature imports |

`MaterialApp` uses `theme: AppTheme.light` in `main.dart`. **New screens:** import `core/theme/theme.dart`, use `context.textStyles`, `context.brand`, `context.colors`, and `AppMetrics` — do not add inline `GoogleFonts` or one-off hex in features. Shared widgets (`OnboardingHeadline`, `OnboardingPrimaryButton`, home shell) already use this layer.

### Reset dev test data (babies + onboarding)

Cloud SQL Auth Proxy + `DB_PASSWORD` (see [migrations/README.md](../../infra/db/migrations/README.md)):

```bash
cd infra/db
DB_PASSWORD="$PGPASSWORD" DB_PORT=5433 python clear_dev_test_data.py \\
  --email your@email.com --reset-onboarding
```

Clears babies and related rows for that user and clears `owner_onboarding_completed_at` so you can run owner onboarding again. Use `--dry-run` first; `--verbose` lists GCS `display/` paths (objects are not deleted from GCS).

## API rate limiting

Sensitive routes (`POST /v1/photos/init`, `POST …/invitations/batch`) use an **in-process** per-IP sliding window in `middleware/rate_limit.py` (30 requests / 60s per path per instance). Cloud Run scales horizontally, so the **effective** cap is roughly `30 × instance count` until you add a shared limiter (e.g. Cloud Armor, Redis/Memorystore) at the edge. No shared limiter is deployed in v1; document and monitor before wide public beta.

## Firebase JWT audiences

API verifies Firebase ID tokens with `firebase_admin.auth.verify_id_token`, then checks the token `aud` claim against `Settings.firebase_audience_allowlist()` (`GCP_PROJECT_ID` when `FIREBASE_AUDIENCES` is unset). Sideloaded dev APKs and emulators using the same Firebase project are unaffected. Misconfigured `FIREBASE_AUDIENCES` causes 401 for all real clients.

## API and worker

| Service | Cloud Run name | Deploy |
|--------|----------------|--------|
| API | `api` | `services/api/scripts/deploy.sh` |
| Worker | `worker` | `services/worker/scripts/deploy.sh` then `./scripts/apply-dev-run-iam.sh` |

Dev API base URL: `apps/mobile/flavors/dev.json` → `API_BASE_URL` (sync steps: [flavors/README.md](../../apps/mobile/flavors/README.md); `gcloud run services describe api --region=us-central1 --format='value(status.url)'`)

| Method | Path | Auth |
|--------|------|------|
| GET | `/health` | Public liveness (`status`, `environment`) |
| GET | `/v1/app/version?platform=` | Public force-update config (`android` \| `ios`); `minimum_version`, `store_url` (migration `020_app_versions`; no JWT / App Check) |
| GET | `/v1/me/account` | Firebase Bearer JWT; profile + babies + `engagement` stats; `storage_usage` when user owns a baby. Auth smoke: unauthenticated request → 401. |
| GET, PATCH | `/v1/me/notification-preferences` | Digest (`realtime`/`daily`/`weekly`), push + email digest toggles; per-channel `notify_*_enabled` (`gallery`, `calendar`, `registry`, `comments`) |
| GET | `/v1/me/notifications` | In-app notification inbox |
| GET | `/v1/me/notifications/unread-count` | Unread inbox count (shell bell dot) |
| PATCH | `/v1/me/notifications/{id}/read` | Mark notification read |
| PUT, DELETE | `/v1/me/device-tokens` | Register or remove FCM device token (`platform`: `ios` \| `android`) |
| GET | `/v1/me/delete-account/eligibility` | Account deletion preflight (`allowed: true`; no blockers) |
| POST | `/v1/me/delete-account` | Delete Firebase user; soft-delete sole-owned baby profiles; remove user memberships; anonymize SQL profile |
| GET | `/v1/babies/{baby_profile_id}/search?q=` | Cross-feature search (member) |
| POST | `/v1/babies/{baby_profile_id}/data-export` | Queue baby JSON export (owner) |
| GET | `/v1/babies/{baby_profile_id}/data-export/latest` | Export job status + signed download URL |
| PATCH | `/v1/profile` | Firebase Bearer JWT; mobile updates display name (onboarding + account edit). Read profile via `GET /v1/me/account`. |
| GET | `/v1/onboarding/status` | Firebase Bearer JWT |
| POST | `/v1/onboarding/owner/complete` | Firebase Bearer JWT |
| GET, POST | `/v1/babies` | Firebase Bearer JWT |
| PATCH | `/v1/babies/{baby_profile_id}` | Firebase Bearer JWT (owner); optional `avatar_url`; `lifecycle_status: born` records `baby_arrived` activity |
| GET | `/v1/babies/{baby_profile_id}/home-summary` | Firebase Bearer JWT (member); §6.2 blocks: `birth_welcome`, `system_announcements`, `teasers` (notifications, upcoming events, RSVP, photos, registry), owner `new_followers` / `invite_status`, `recent_activity` teaser |
| GET | `/v1/babies/{baby_profile_id}/activity-events` | Paginated `activity_events` (`limit`, `offset`) |
| POST | `/v1/me/system-announcements/{id}/dismiss` | Dismiss system banner |
| GET/POST/PATCH/DELETE | `/v1/admin/system-announcements` | Ops CRUD (`X-Admin-Key` header; Cloud Run secret `admin-api-key` → env `ADMIN_API_KEY`) |
| GET | `/v1/babies/{baby_profile_id}/members` | Firebase Bearer JWT (owner); members list |
| GET | `/v1/babies/{baby_profile_id}/invitations` | Firebase Bearer JWT (owner); pending invites |
| DELETE | `/v1/babies/{baby_profile_id}/invitations/{invitation_id}` | Firebase Bearer JWT (owner); revoke pending |
| GET, PUT | `/v1/babies/{baby_profile_id}/announcement` | JWT; birth announcement keepsake; GET includes `photo_display_url` when `photo_id` set |
| POST | `/v1/babies/{baby_profile_id}/announcement/squish` | JWT; toggle squish |
| POST | `/v1/babies/{baby_profile_id}/announcement/comments` | JWT; add comment |
| POST | `/v1/babies/{baby_profile_id}/onboarding/first-moment` | Firebase Bearer JWT (owner) |
| GET | `/v1/babies/{baby_profile_id}/membership-check?email=` | Firebase Bearer JWT (owner) |
| POST | `/v1/babies/{baby_profile_id}/invitations/batch` | Firebase Bearer JWT (owner); queues `send_invite_email` on Pub/Sub |
| GET | `/v1/invitations/preview?token=` | Public (invite deep link) |
| POST | `/v1/invitations/accept` | Firebase Bearer JWT + App Check; invitee email must match. Errors: **404** `not_found`, **410** `expired`, **403** `email_mismatch` (detail includes emails), **409** `max_owners` — JSON `detail.error` (mobile maps to `InvitationAcceptResult`) |
| POST | `/v1/uploads/display/signed-url` | JWT + App Check; avatar upload init: `content_type`, `byte_length` (≤ 2 MB), `scope` (`user` \| `baby`), optional `baby_profile_id` when `scope=baby`. Returns signed PUT + `object_path` under `avatars/`; persist path as `avatar_url`. Reads mint signed GET URLs on account/baby responses (900s TTL). Legacy `smoke/` paths still supported. |
| POST | `/v1/photos/init` | Firebase Bearer JWT (owner; gallery upload init); optional `caption` (max 2000) |
| GET | `/v1/babies/{id}/photos` | JWT (member); `limit`/`offset`; `sort=default\|recent\|favorites`; followers see `ready` only |
| GET, PATCH, DELETE | `/v1/babies/{id}/photos/{photo_id}` | JWT (member read; owner mutate); signed thumb/display URLs; GET includes `tagged_babies` |
| POST | `/v1/babies/{id}/photos/{photo_id}/squish` | JWT (member); toggle squish |
| POST, PATCH, DELETE | `/v1/babies/{id}/photos/{photo_id}/comments` | JWT (member; PATCH author-only) |
| PUT | `/v1/babies/{id}/photos/{photo_id}/tags` | JWT (owner); body `tagged_baby_profile_ids` |
| GET, POST | `/v1/babies/{id}/events` | JWT (member read; owner create); query `month=YYYY-MM`, `upcoming=true` |
| GET, PATCH, DELETE | `/v1/babies/{id}/events/{event_id}` | JWT |
| PUT | `/v1/babies/{id}/events/{event_id}/rsvp` | JWT (member); body `{status}` |
| POST, PATCH, DELETE | `/v1/babies/{id}/events/{event_id}/comments` | JWT (member; PATCH author-only) |
| GET, POST | `/v1/babies/{id}/registry/items` | JWT (member read; owner create) |
| GET, PATCH, DELETE | `/v1/babies/{id}/registry/items/{item_id}` | JWT; no PATCH when purchased |
| POST, DELETE | `/v1/babies/{id}/registry/items/{item_id}/purchase` | JWT (claim / undo) |
| GET, PATCH | `/v1/babies/{id}/registry/shipping-address` | JWT read; owner PATCH |
| GET, POST, DELETE | `/v1/babies/{id}/fun/names` | JWT (member); follower 1 name/gender |
| POST | `/v1/babies/{id}/fun/names/{id}/like` | JWT; one like per gender column |
| GET | `/v1/babies/{id}/fun/predictions` | JWT |
| PUT | `/v1/babies/{id}/fun/predictions/gender`, `.../birthdate` | JWT |

Local API env: `services/api/.env.example`. DB password and Mailjet keys live in **Secret Manager**.

**Local API tests** (after `pip install -r services/api/requirements.txt` in `services/api/.venv`):

```bash
cd services/api
PYTHONPATH=src .venv/bin/pytest -q
```

Covers gallery/calendar/registry/fun domain rules (`services/api/tests/`). CI runs the same suite on push/PR to `main`.

**Invite emails (FR-INV-004 / FR-INV-007):** batch create publishes `{"type":"send_invite_email","invitation_id","invite_token"}` to the `photo-upload-finalized` topic; the worker sends Mailjet HTML from `invite_v1` templates. Set worker env `MAILJET_*` and `INVITE_DEEP_LINK_BASE` (default `lanonna://app`). Link shape: `lanonna://app/invite-accept?token=…` (+ `&role=owner` for co-owner). Flutter uses `app_links` to set GoRouter `initialLocation` on cold start and `go()` on warm opens (`core/deep_links/`). Local API can set `INVITE_EMAIL_PUBLISH_DISABLED=true` to skip Pub/Sub while testing accept/preview.

**Pre-beta device QA:** [pre-beta-qa.md](pre-beta-qa.md) (App Check, encode, cache, push, deep links, invite cold start).

**Cold-start invite QA (app must be killed first):**

- Android: `adb shell am start -a android.intent.action.VIEW -d 'lanonna://app/invite-accept?token=TOKEN'`
- iOS Simulator: `xcrun simctl openurl booted 'lanonna://app/invite-accept?token=TOKEN'`
- Expect `/invite-accept` → preview API → follower or co-owner onboarding. Mid-flow kill + relaunch without link should resume via stored `pendingInviteToken` (`AppSession.redirectFor`).
- Disable `DEV_AUTO_SIGN_IN_*` dart-defines when testing unsigned invite UX.

**In-app + push notifications:** API `domain/notifications.py` publishes `notify_fan_out` or `notify_user` to the `photo-upload-finalized` topic; the worker handles the same types on `POST /pubsub/push` and inserts `notifications` rows. **Instant FCM** only when `push_notifications_enabled` and `notification_digest=realtime`. **`daily`** digest: in-app inbox only (no batch push). **`weekly`** digest: one summary push (Sunday 14:00 UTC) via Cloud Scheduler → Pub/Sub `{"type":"weekly_notification_digest"}` (`./scripts/setup-weekly-digest-scheduler.sh`; optional manual `POST /cron/weekly-notification-digest` on worker).

| Trigger | Publisher | Audience |
|---------|-----------|----------|
| Photo ready | Worker after thumb | Baby members (excl. uploader) |
| Photo squish / comment | API gallery domain | Photo uploader |
| Calendar event created | API calendar | Baby members (excl. creator) |
| RSVP | API calendar | Event creator |
| Registry purchase claimed | API registry | Baby owners (excl. buyer) |
| Baby arrived (announce) | API home PATCH | Baby members (excl. owner) |
| Invite accepted | API accept | Inviter |

API local dev: `NOTIFY_PUBLISH_DISABLED=true`. Mobile: `firebase_messaging`, `PushNotificationService` → `PUT`/`DELETE /v1/me/device-tokens` on auth; opens `deep_link` from FCM data. Worker SA: `roles/firebasecloudmessaging.admin` on dev if sends fail.

**Invite onboarding QA (FR-ONB-011):**

| Deep link role | Expected path after profile |
|----------------|----------------------------|
| `invited_role=follower` | S08 follower invite → auth → S09 relationship → S10 carousel → follower Home |
| `invited_role=owner` (co-owner invite) | S08 co-owner invite → auth → co-owner welcome → owner-style Home |

Preview includes `lifecycle_status` and birth dates for invite subtitles and carousel slide 4. Wrong Google/email account → `/onboarding/wrong-email`.

## Database

Apply SQL files in order from `infra/db/migrations/` (`001`–`021`; see [migrations/README.md](../../infra/db/migrations/README.md)). Cloud SQL Auth Proxy may use port **5432** or **5433** — set `DB_PORT` consistently (`apply_migrations.py` defaults to **5432**; Maestro, `clear_dev_test_data.py`, and `verify-dev-migrations.sh` default to **5433**). Cloud SQL via Auth Proxy + `infra/db/apply_migrations.py` or `psql -f` per file. Use the venv under `infra/db/.venv` (`pip install psycopg`) or any environment with `psycopg` installed.

| Script | Purpose |
|--------|---------|
| `apply_migrations.py` | Runs every `migrations/*.sql` in lexicographic order (DDL is idempotent; safe to re-run on dev) |
| `clear_dev_test_data.py` | Delete baby-domain rows for a test user; optional `--reset-onboarding` |

Set `DB_HOST`, `DB_PORT` (e.g. `5433` if 5432 is in use), `DB_PASSWORD`, and `DB_USER` / `DB_NAME` as needed (defaults match dev Cloud SQL via proxy).

## Related reading

- [remediation-plan.md](remediation-plan.md) — codebase gap remediation (phased)
- [building-the-app.md](building-the-app.md) — prerequisite gate
- [initial-setup.md](initial-setup.md) — Terraform, deploy, secrets
- [platform-architecture.md](platform-architecture.md) — media flow, costs, playbook
