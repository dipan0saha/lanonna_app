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
└── .github/workflows/       # CI (Flutter + Python compile)
```

**Deploy model:** `api` and `worker` ship as **two Cloud Run services** — see [platform-architecture.md](platform-architecture.md).

**Before main product work:** [building-the-app.md](building-the-app.md) and `./scripts/verify-dev-prerequisites.sh`.

### Mobile feature modules (`apps/mobile/lib/features/`)

| Module | Shell route | Notes |
|--------|-------------|--------|
| `home/` | `/home` | Owner expecting/born; `home-summary`; announce arrival |
| `gallery/` | `/gallery` | Grid, detail, squish, comments; nested `/gallery/photo/:id` |
| `calendar/` | `/calendar` | Month + upcoming; event CRUD; static AI suggestions asset |
| `registry/` | `/registry` | Needed/purchased, shipping, purchase claim; AI suggestions |
| `fun/` | `/gamification` | Names + Predictions tabs (**Family Fun**) |
| `account/` | `/profile`, `/account/edit`, `/baby/create`, `/baby/:id/edit`, `/baby/:id/followers` | Profile card, baby list, add/edit baby |
| `announcement/` | `/baby/:id/announcement`, `/baby/:id/announcement/create` | Keepsake card (signed `photo_display_url` on GET) + create |
| `shell/` | (sheet from tab `HomeTopBar`) | Baby switcher; **My Account** footer |
| `onboarding/`, `invitations/` | Onboarding + deep links | Owner/follower/co-owner paths |

Repositories are registered in `bootstrap.dart`; routes in `core/router/app_router.dart`. Static catalogs: `assets/calendar/event_suggestions.json`, `assets/registry/registry_suggestions.json`.

### API layout (`services/api/src/lanonna_api/`)

| Layer | Role |
|-------|------|
| `routers/` | HTTP handlers (`photos`, `events`, `registry`, `fun`, `babies`, …) |
| `domain/` | Membership, permissions, activity side-effects (`gallery`, `calendar`, `registry`, `fun`, `home`) |
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

## API and worker

| Service | Cloud Run name | Deploy |
|--------|----------------|--------|
| API | `api` | `services/api/scripts/deploy.sh` |
| Worker | `worker` | `services/worker/scripts/deploy.sh` then `./scripts/apply-dev-run-iam.sh` |

Dev API URL: `https://api-1008830071001.us-central1.run.app`

| Method | Path | Auth |
|--------|------|------|
| GET | `/health` | Public |
| GET | `/v1/me` | Firebase Bearer JWT; minimal auth smoke (`uid`, email). **Contract endpoint** — mobile uses `/v1/me/account` instead. |
| GET | `/v1/me/account` | Firebase Bearer JWT; profile + babies + `engagement` stats; `storage_usage` when user owns a baby |
| GET, PATCH | `/v1/profile` | Firebase Bearer JWT; mobile **PATCH**es display name (onboarding + account edit). **GET** is contract/PRD — not called by the Flutter app today. |
| GET | `/v1/onboarding/status` | Firebase Bearer JWT |
| POST | `/v1/onboarding/owner/complete` | Firebase Bearer JWT |
| GET, POST | `/v1/babies` | Firebase Bearer JWT |
| PATCH | `/v1/babies/{baby_profile_id}` | Firebase Bearer JWT (owner); `lifecycle_status: born` records `baby_arrived` activity |
| GET | `/v1/babies/{baby_profile_id}/home-summary` | Firebase Bearer JWT (member); family insight, next event, recent activity; getting started owner-only |
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
| POST | `/v1/invitations/accept` | Firebase Bearer JWT; invitee email must match |
| POST | `/v1/uploads/display/signed-url` | Firebase Bearer JWT (smoke / legacy path) |
| POST | `/v1/photos/init` | Firebase Bearer JWT (owner; gallery upload init) |
| GET | `/v1/babies/{id}/photos` | JWT (member); `limit`/`offset`; followers see `ready` only |
| GET, PATCH, DELETE | `/v1/babies/{id}/photos/{photo_id}` | JWT (member read; owner mutate); signed thumb/display URLs |
| POST | `/v1/babies/{id}/photos/{photo_id}/squish` | JWT (member); toggle squish |
| POST, PATCH, DELETE | `/v1/babies/{id}/photos/{photo_id}/comments` | JWT (member) |
| GET, POST | `/v1/babies/{id}/events` | JWT (member read; owner create); query `month=YYYY-MM`, `upcoming=true` |
| GET, PATCH, DELETE | `/v1/babies/{id}/events/{event_id}` | JWT |
| PUT | `/v1/babies/{id}/events/{event_id}/rsvp` | JWT (member); body `{status}` |
| POST, PATCH, DELETE | `/v1/babies/{id}/events/{event_id}/comments` | JWT (member) |
| GET, POST | `/v1/babies/{id}/registry/items` | JWT (member read; owner create) |
| GET, PATCH, DELETE | `/v1/babies/{id}/registry/items/{item_id}` | JWT; no PATCH when purchased |
| POST, DELETE | `/v1/babies/{id}/registry/items/{item_id}/purchase` | JWT (claim / undo) |
| GET, PATCH | `/v1/babies/{id}/registry/shipping-address` | JWT read; owner PATCH |
| GET, POST, DELETE | `/v1/babies/{id}/fun/names` | JWT (member); follower 1 name/gender |
| POST | `/v1/babies/{id}/fun/names/{id}/like` | JWT; one like per gender column |
| GET | `/v1/babies/{id}/fun/predictions` | JWT |
| PUT | `/v1/babies/{id}/fun/predictions/gender`, `.../birthdate` | JWT |
| PATCH | `/v1/babies/{id}/fun/predictions/anonymous` | JWT |

Local API env: `services/api/.env.example`. DB password and Mailjet keys live in **Secret Manager**.

**Local API tests** (after `pip install -r services/api/requirements.txt` in `services/api/.venv`):

```bash
cd services/api
PYTHONPATH=src .venv/bin/pytest -q
```

Covers gallery/calendar/registry/fun domain rules (`services/api/tests/`). CI runs the same suite on push/PR to `main`.

**Invite emails (FR-INV-004):** batch create publishes `{"type":"send_invite_email","invitation_id","invite_token"}` to the `photo-upload-finalized` topic; the worker sends Mailjet HTML from `invite_v1` templates. Set worker env `MAILJET_*` and `INVITE_DEEP_LINK_BASE` (default `lanonna://app`). Local API can set `INVITE_EMAIL_PUBLISH_DISABLED=true` to skip Pub/Sub while testing accept/preview. Test deep link on Android: `adb shell am start -a android.intent.action.VIEW -d 'lanonna://app/invite-accept?token=TOKEN'`.

**Invite onboarding QA (FR-ONB-011):**

| Deep link role | Expected path after profile |
|----------------|----------------------------|
| `invited_role=follower` | S08 follower invite → auth → S09 relationship → S10 carousel → follower Home |
| `invited_role=owner` (co-owner invite) | S08 co-owner invite → auth → co-owner welcome → owner-style Home |

Preview includes `lifecycle_status` and birth dates for invite subtitles and carousel slide 4. Wrong Google/email account → `/onboarding/wrong-email`.

## Database

Apply SQL files in order from `infra/db/migrations/` (`001`–`009`; see [migrations/README.md](../../infra/db/migrations/README.md)). Cloud SQL via Auth Proxy + `infra/db/apply_migrations.py` or `psql -f` per file. Use the venv under `infra/db/.venv` (`pip install psycopg`) or any environment with `psycopg` installed.

| Script | Purpose |
|--------|---------|
| `apply_migrations.py` | Runs every `migrations/*.sql` in lexicographic order (DDL is idempotent; safe to re-run on dev) |
| `clear_dev_test_data.py` | Delete baby-domain rows for a test user; optional `--reset-onboarding` |

Set `DB_HOST`, `DB_PORT` (e.g. `5433` if 5432 is in use), `DB_PASSWORD`, and `DB_USER` / `DB_NAME` as needed (defaults match dev Cloud SQL via proxy).

## Related reading

- [building-the-app.md](building-the-app.md) — prerequisite gate
- [initial-setup.md](initial-setup.md) — Terraform, deploy, secrets
- [platform-architecture.md](platform-architecture.md) — media flow, costs, playbook
