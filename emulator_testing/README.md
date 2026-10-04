# Emulator testing (La Nonna)

Notes from real device/emulator QA (including account delete [#388](https://github.com/dipan0saha/nonna_app/issues/388)). Intended for humans and agents running tests on **lanonna-dev**.

## Prerequisites

| Item | Notes |
|------|--------|
| Emulator | Android AVD; confirm `adb devices` shows e.g. `emulator-5554` |
| Flutter | `apps/mobile`, `flavors/dev.json` → dev Cloud Run API |
| API changes | **Deploy** before UI E2E: `services/api/scripts/deploy.sh` (local mobile hits remote API) |
| Cloud SQL (backend checks) | `cloud-sql-proxy lanonna-dev:us-central1:lanonna-db --port 5433` + `PGPASSWORD` from Secret Manager |
| Maestro | CLI on PATH; see [`apps/mobile/maestro/README.md`](../apps/mobile/maestro/README.md) |
| Firebase App Check | Dev deploy defaults `APP_CHECK_ENFORCE=false`; client still sends token when available |

**Do not use** Maestro smoke credentials (`lanonna.dev.smoke@test.com`) for destructive flows (account delete).

---

## Recommended ways to test on emulator

### 1. Manual (most reliable for full-stack)

```bash
cd apps/mobile
flutter run -d emulator-5554 --dart-define-from-file=flavors/dev.json
```

- **Do not** pass `DEV_AUTO_SIGN_IN_*` unless you intentionally want auto sign-in.
- If an old release APK is installed (`versionCode` 2001 vs debug `1`), uninstall or use `flutter run` to avoid `INSTALL_FAILED_VERSION_DOWNGRADE`.

**Disposable account pattern**

1. Create user in Firebase (Admin SDK or Console): `email_verified=true`.
2. Via API with ID token: `PATCH /v1/profile`, `POST /v1/babies`, `POST /v1/onboarding/owner/complete`.
3. Sign in on emulator with email/password (type manually; avoid autofill typos on passwords with `!`).

**Account delete happy path (FR-SET-005)**

1. Home → tap **center title** (baby name) → **My Account**.
2. **Delete account** → confirm copy → **Delete my account**.
3. Expect onboarding carousel (`Skip` / **I already have an account**), not main tabs.

### 2. Maestro (UI automation)

Build/install with semantics (required for `tapOn: id:`):

```bash
cd apps/mobile
./maestro/scripts/build-install.sh
# Optional faster path when testing signed-in flows:
# MAESTRO_AUTO_LOGIN=1 + maestro/local.env (smoke user only — not for delete tests)
```

Run a flow:

```bash
export ANDROID_SERIAL=emulator-5554
maestro --udid=emulator-5554 test --reinstall-driver maestro/flows/...
```

**Learnings**

| Topic | Detail |
|-------|--------|
| Driver flakes | `Device server died during deviceInfo` → `adb kill-server && adb start-server`, retry `--reinstall-driver`; ensure one emulator (`ANDROID_SERIAL`) |
| Baby switcher | Tapping `id: shell_baby_switcher` did not always open the sheet; **`id: shell_baby_title`** (center title) was reliable |
| Long copy | Use regex: `visible: ".*solely owned by your account.*"` not exact substring |
| Post-delete assert | Allow `I already have an account\|Skip\|Welcome back`; increase timeout (delete + sign-out can take 60–90s) |
| Auto sign-in APK | Build with `--dart-define=DEV_AUTO_SIGN_IN_EMAIL=...` **only** for flows that should skip login; rebuild without for manual credential tests |

Existing subflows: `maestro/flows/subflows/open_account.yaml` (may need title tap fix for your flow).

### 3. Flutter `integration_test` on device

```bash
flutter test integration_test/<file>.dart -d emulator-5554 \
  --dart-define-from-file=flavors/dev.json \
  --dart-define=DEV_AUTO_SIGN_IN_EMAIL=... \
  --dart-define=DEV_AUTO_SIGN_IN_PASSWORD=...
```

**Learnings**

- Host often kills the run around **~30–45s** with `did not complete [E]` if the test uses long `pumpAndSettle` or many waits.
- Prefer **bounded** `await tester.pump(Duration(seconds: 1))` loops with early exit on keys.
- `bootstrapLaNonnaApp()` auto sign-in only runs in **debug** when `DEV_AUTO_SIGN_IN_*` dart-defines are set at **build** time.
- For long E2E, Maestro or manual testing is usually less painful than integration_test on device.

---

## Backend verification (after emulator delete)

Confirm the fix on **lanonna-dev**, not only UI.

### Firebase Auth

- Deleted user: `firebase_admin.auth.get_user(uid)` → `UserNotFoundError`.
- Sign-in REST with password should fail for deleted users.

### PostgreSQL (proxy on 5433)

```sql
-- Anonymized account
SELECT firebase_uid, display_name, email, deleted_at
FROM app_users WHERE firebase_uid = '<uid>';

-- Sole-owned baby soft-deleted (timestamps often match delete transaction)
SELECT id, name, deleted_at FROM baby_profiles WHERE name = '...';

-- Memberships removed
SELECT * FROM baby_memberships WHERE firebase_uid = '<uid>';
```

Successful delete (#388): `display_name = 'Deleted user'`, `email` NULL, `deleted_at` set; sole-owned baby `deleted_at` set; memberships `removed_at` set.

### API

With a valid token **before** delete: `GET /v1/me/delete-account/eligibility` → `allowed: true`, `blockers: []`.  
`POST /v1/me/delete-account` body `{"confirm": true}` → `{"status":"deleted"}`.

---

## Infra gotcha: account delete on Cloud Run

If the app shows **“Could not delete Firebase user”** (API 503):

- Cloud Run service account `lanonna-api@lanonna-dev.iam.gserviceaccount.com` needs **`roles/firebaseauth.admin`** for `firebase_auth.delete_user`.
- Documented in [`infra/gcp/SETUP.md`](../infra/gcp/SETUP.md) and Terraform `api_firebase_auth_admin` in `infra/terraform/modules/platform/iam.tf`.
- IAM change is immediate; no API redeploy required for the role itself.

---

## Create-baby profile photo vs gallery (#394)

Manual on emulator (`flutter run` **without** `DEV_AUTO_SIGN_IN_*`):

1. Owner onboarding → **Create your baby's profile** → add profile photo.
2. Leave **Also share this photo in the gallery** unchecked → Continue → finish or skip first moment → **Gallery** tab: expect empty (no auto-upload).
3. Repeat with a fresh account (or second run): check **Also share…** → expect one gallery photo after upload; baby avatar still on profile / edit baby.

---

## Batch invite from home (#401 / FR-INV-008)

Owner signed in on emulator (no auto-login):

1. **My Account** → **Invite family & friends** (or Home invite action / Manage followers → **+ Invite more people**).
2. Expect **one** top row: back + **Invite Family & Friends** (no baby-name home bar stacked above).
3. Intro inset matches form (`AppMetrics.horizontalPadding`); private link expires in **7 days**; sage 💡 hint for **Mother/Father** co-owner.
4. Relationship dropdown shows **Mother/Father** (not Wife/Husband); co-owner row badge when selected.
5. Send with a valid email → returns to previous screen; pending invite visible under followers when applicable.

---

## Email verification (FR-AUTH-002 / #390)

1. Apply templates to dev: `bash scripts/sync-firebase-auth-templates.sh apply` (from repo root).
2. Fresh email/password sign-up on emulator (no `DEV_AUTO_SIGN_IN_*`).
3. Inbox: subject **Confirm your email for La Nonna**, body has **Verify my email** button (not copy/paste-only).
4. Tap link: app opens (Android) or browser verifies then **Continue** on verify screen works.
5. **Resend email** after ~60s if testing rate-limit copy.

Simulate auth action link on Android:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d 'https://lanonna-dev.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=TEST'
```

(Use a real `oobCode` from a test email for a successful apply.)

---

## Cleaning up disposable test data

**Email patterns used in QA:** `lanonna.del.*@gmail.com`, `lanonna.delete.test.*@gmail.com`.

1. Delete Firebase users (Admin SDK `list_users` + filter by email prefix).
2. SQL: delete in FK order — invitations → `baby_memberships` → `baby_profiles` → `app_users` for those UIDs (or use [`infra/db/clear_dev_test_data.py`](../infra/db/clear_dev_test_data.py) per email with `--delete-app-user` when appropriate).

Do not delete smoke/Maestro fixture users.

---

## Quick troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| Wrong auth credential on login | Typo/autofill; clear app data; simpler password; verify `lanonna-dev` in `firebase_options.dart` / `google-services.json` |
| Delete button disabled (old builds) | Pre-#388 API still blocking sole owners; deploy API + update app |
| Could not delete Firebase user | Missing `firebaseauth.admin` on API SA (see above) |
| Maestro fails immediately on driver | ADB/Maestro driver; restart adb, `--reinstall-driver`, single device |
| API works in script but not app | Old APK, wrong `API_BASE_URL`, or App Check (rare on dev with enforce off) |

---

## Related docs

- [pre-beta-qa.md](../docs/engineering/pre-beta-qa.md) — § Account delete (FR-SET-005)
- [development.md](../docs/engineering/development.md) — delete-account routes
- [maestro/README.md](../apps/mobile/maestro/README.md) — credentials, smoke suite
