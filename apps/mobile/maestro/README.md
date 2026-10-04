# Maestro E2E (Android)

UI tests for the La Nonna Flutter app on an Android emulator or device. Selectors use Flutter `Semantics.identifier` values (`tapOn: id: …`) defined in `lib/core/widgets/app_semantics.dart` and feature screens.

## Prerequisites

- [Maestro CLI](https://maestro.mobile.dev/getting-started/installing-maestro) (`~/.maestro/bin` on PATH)
- `adb` device or emulator (e.g. `emulator-5554`)
- `apps/mobile/flavors/dev.json` (API URL, not committed if local-only)
- Firebase **App Check** debug token registered for the emulator ([pre-beta-qa.md](../../../docs/engineering/pre-beta-qa.md)) — required for onboarding/API calls during cold-start flows
- Cloud SQL Auth Proxy on `127.0.0.1:5433` (same as `infra/db/clear_dev_test_data.py`); `provision-smoke-user.sh` loads `DB_PASSWORD` from Secret Manager when `gcloud` is available
- After `pm clear` / cold start, register the emulator App Check debug token (see logcat `Firebase App Check debug token: …`):

```bash
firebase appcheck:debugtokens:create YOUR_TOKEN \
  --app 1:1008830071001:android:0144f51dbc29e9a94abec8 \
  --project lanonna-dev --force
```
- Dev smoke user with at least one baby on **lanonna-dev**

## Credentials

Copy `local.env.example` to `local.env` (gitignored):

| Variable | Example |
|----------|---------|
| `SMOKE_TEST_EMAIL` | `lanonna.dev.smoke@test.com` |
| `SMOKE_TEST_PASSWORD` | Team / Firebase dev password |

Password is **never** committed to git.

## Run

From `apps/mobile`:

```bash
chmod +x maestro/scripts/*.sh

# Build debug APK (dev flavor) and install
./maestro/scripts/build-install.sh

# Full suite (provision → build/install → App Check prep → all flows)
./maestro/scripts/run-maestro.sh

# Sign-in flow only (same App Check prep, then `auth_sign_in.yaml`)
./maestro/scripts/run-auth-sign-in.sh
```

`prepare-emulator-for-maestro.sh` runs automatically: after `pm clear`, first launch emits a new App Check debug token (registered via Firebase CLI), then the app is relaunched so API calls succeed. Fresh installs from `build-install.sh` need this too.

Flow timeouts are intentionally short (mostly 10–45s) so failures surface quickly; a green run should finish in a few minutes, not ~3 minutes per stuck step.

### Fixing failures

Flows run **one at a time** (`run-maestro-flows-sequential.sh` stops on the first failure). When something breaks:

1. Fix the app or YAML, then **resume from that flow** (and any later flows you have not green yet)—no need to rerun smoke flows that already passed.
2. After every flow is green in isolation or in chunks, run **`./maestro/scripts/run-maestro-full.sh` once** end-to-end as the final gate.

Resume example (from `apps/mobile`, same env as full run):

```bash
source maestro/scripts/maestro-env-args.sh
./maestro/scripts/run-maestro-flows-sequential.sh \
  maestro/flows/features/baby_switcher.yaml \
  maestro/flows/features/calendar_create.yaml
  # …remaining paths from run-maestro-full.sh
```

Single flow: `maestro test maestro/flows/features/foo.yaml "${MAESTRO_ENV_ARGS[@]}"`

**Faster local runs** (debug APK with `DEV_AUTO_SIGN_IN_*`; skips `auth_sign_in.yaml`):

```bash
./maestro/scripts/run-maestro-autologin.sh
```

### Flutter integration tests (device / emulator)

CI runs `flutter test` (unit/widget) only. Device integration tests live under `integration_test/` and are run manually when you have smoke credentials in `maestro/local.env`:

```bash
source maestro/scripts/load-env.sh
flutter test integration_test/home_summary_load_test.dart -d emulator-5554 \
  --dart-define-from-file=flavors/dev.json \
  --dart-define=DEV_AUTO_SIGN_IN_EMAIL="$SMOKE_TEST_EMAIL" \
  --dart-define=DEV_AUTO_SIGN_IN_PASSWORD="$SMOKE_TEST_PASSWORD"
```

`integration_test/smoke_sign_in_test.dart` uses `--dart-define=SMOKE_TEST_EMAIL` / `SMOKE_TEST_PASSWORD` instead of auto-login defines.

## Flows (`maestro test maestro/flows/…`)

| Flow | Purpose |
|------|---------|
| `flows/auth_sign_in.yaml` | `clearState` → sign in → home |
| `flows/shell_navigation.yaml` | All five bottom tabs via `nav_*` ids |
| `flows/open_search.yaml` | `shell_search` → `search_field` |
| `flows/open_notifications.yaml` | `shell_notifications` → inbox |

Subflows live under `flows/subflows/`.

## Semantics IDs (convention)

| Prefix | Examples |
|--------|----------|
| `nav_*` | `nav_home`, `nav_gallery`, … |
| `shell_*` | `shell_search`, `shell_notifications`, `shell_baby_switcher` |
| `auth_*` | `auth_login_email`, `auth_sign_in` |
| Feature | `home_section_list`, `gallery_upload_fab`, `search_field`, `notifications_inbox` |

Add new IDs via `AppSemantics` when exposing UI for Maestro.
