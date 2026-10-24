# P0 end-to-end automation (Maestro × Android emulator)

Automated coverage for the P0 cases in [`pre-prod-test-plan.md`](pre-prod-test-plan.md) (source branch `cursor/pre-prod-qa-test-plan-1a80`, PR #363). Flows live under `apps/mobile/maestro/flows/`; the repo entrypoint is [`scripts/e2e/run_smoke.sh`](../../scripts/e2e/run_smoke.sh).

## Prerequisites (local / pre-merge)

1. Android emulator running (`emulator-5554` on Dipan's Mac, or set `ANDROID_SERIAL`).
2. [Maestro CLI](https://maestro.mobile.dev/) on `PATH` (`~/.maestro/bin`).
3. `apps/mobile/flavors/dev.json` pointing at **lanonna-dev**.
4. Cloud SQL Auth Proxy on `127.0.0.1:5433` for fixture provisioning.
5. Credentials in **one** of (never commit):
   - `~/Neo_Workspace/qa_secrets/lanonna_qa363_accounts.env`
   - `apps/mobile/maestro/local.env`
   - or `LANONNA_QA_ENV_FILE=/path/to/file.env`
6. Firebase App Check debug token registered ([`apps/mobile/maestro/README.md`](../../apps/mobile/maestro/README.md)).

## Run

From the repository root:

```bash
chmod +x scripts/e2e/run_smoke.sh scripts/e2e/prereq/*.sh apps/mobile/maestro/scripts/*.sh

# Critical path (~15 min target)
./scripts/e2e/run_smoke.sh --smoke

# Full P0 UI suite
./scripts/e2e/run_smoke.sh --full

# Tagged subset (invite, auth, registry, destructive)
./scripts/e2e/run_smoke.sh --tag invite

# Single flow
./scripts/e2e/run_smoke.sh --skip-provision --flow maestro/flows/smoke/auth_sign_in.yaml
```

Artifacts (JUnit + failure screenshots) go to `.e2e-out/run-<timestamp>/` (gitignored). The script exits non-zero on the first failing flow.

Legacy wrappers under `apps/mobile/maestro/scripts/run-maestro*.sh` remain; prefer `scripts/e2e/run_smoke.sh` for CI and pre-merge.

## Tags

| Tag | Intent |
|-----|--------|
| **smoke** | Auth shell, home, offline banner, pull-to-refresh, sign-out |
| **full** | smoke + gallery/calendar/registry/invites/onboarding/destructive |

Flow lists are defined in [`scripts/e2e/flows-manifest.sh`](../../scripts/e2e/flows-manifest.sh).

## Environment variables (names only)

| Variable | Purpose |
|----------|---------|
| `SMOKE_TEST_EMAIL` | Primary owner smoke account |
| `SMOKE_TEST_PASSWORD` | Password for smoke + default follower/onboarding |
| `FOLLOWER_TEST_EMAIL` | Follower account |
| `FOLLOWER_TEST_PASSWORD` | Follower password |
| `ONBOARDING_TEST_EMAIL` | Dedicated owner onboarding user |
| `ONBOARDING_TEST_PASSWORD` | Onboarding user password |
| `THROWAWAY_TEST_EMAIL` | Optional fixed throwaway (else generated per run) |
| `THROWAWAY_TEST_PASSWORD` | Throwaway password |
| `UNVERIFIED_TEST_EMAIL` | Optional fixed unverified user |
| `UNVERIFIED_TEST_PASSWORD` | Unverified user password |
| `E2E_SIGNUP_EMAIL` / `E2E_SIGNUP_PASSWORD` | Sign-up UI flow (defaults per run) |
| `APP_CHECK_DEBUG_TOKEN` | Stable App Check debug UUID |
| `DB_PASSWORD` / `PGPASSWORD` | Cloud SQL (else loaded via gcloud secret) |
| `LANONNA_QA_ENV_FILE` | Override credentials file path |
| `ANDROID_SERIAL` | ADB device (default `emulator-5554`) |
| `E2E_OUTPUT_DIR` | Artifact root (default repo `.e2e-out`) |

## P0 coverage map

| ID | Automation | Maestro flow / notes |
|----|------------|----------------------|
| ENV-001–003 | **manual** | Deploy/migrations/local build — ops checklist |
| ENV-005 | **manual** | App Check enforce rehearsal |
| ENV-006 | **fixture** | `provision_maestro_fixtures.py all` via runner |
| MULTI-001 | **manual** | FCM while backgrounded — two devices/emulators |
| MULTI-002 | **automated** | `roles/invite_wrong_account_switch.yaml` |
| MULTI-008 | **partial** | `roles/registry_claim_follower.yaml` (claim UI; anonymity copy not asserted) |
| MULTI-010 | **automated** | `destructive/baby_hard_delete_throwaway.yaml` |
| AUTH-001 | **automated** | `features/auth_sign_up_verify_gate.yaml` (stops at verify screen) |
| AUTH-002 | **manual** | Branded email link — no production inbox hook |
| AUTH-003 | **automated** | `features/auth_unverified_gate.yaml` + `unverified_user` fixture |
| AUTH-004 | **automated** | `smoke/auth_sign_in.yaml` |
| AUTH-005 | **manual** | Google sign-in on emulator |
| AUTH-006 | **manual** | Password reset email |
| AUTH-008 | **implicit** | Exercised by all signed-in flows |
| BIO-001 | **partial** | `features/biometric_settings.yaml` (toggle; needs enrolled emulator) |
| BIO-002–006 | **manual** | Cold start / grace / lock policy timing — flaky on CI emulator |
| ONB-002–004 | **automated** | `onboarding/onboarding_owner_fresh.yaml` |
| ONB-007–008 | **partial** | Invite accept / co-owner via `roles/invite_*.yaml` |
| ONB back/background | **automated** | `onboarding/onboarding_owner_resilience.yaml` |
| INV-001–002 | **automated** | Deep link scripts + `roles/invite_*.yaml` |
| INV-003–004 | **partial** | Accept path in invite flows; preview curl not in Maestro |
| INV decline/revoke | **partial** | `roles/invite_decline.yaml`; revoke via `features/followers_revoke_remove.yaml` (owner UI) |
| #427 invite login | **automated** | `roles/invite_login_resume_427.yaml` |
| BABY-001–003 | **partial** | `baby_switcher`, `announce_arrival`, in-app create via account |
| BABY-004 | **automated** | `destructive/baby_hard_delete_throwaway.yaml` |
| BABY-005 | **manual** | Co-owner delete block — needs co-owner fixture |
| HOME-001–002 | **automated** | `smoke/home_summary.yaml`, `features/baby_switcher.yaml` |
| GAL-001–003 | **partial** | `gallery_upload.yaml` opens picker; encode/GCS in integration tests |
| GAL-005–008,010 | **automated** | `gallery_browse.yaml`, `gallery_social.yaml` |
| GAL-012 | **automated** | `roles/follower_permissions.yaml` |
| GAL-013 | **manual** | Offline mid-upload — timing sensitive |
| CAL-001–004 | **partial** | `calendar_upcoming.yaml`, `calendar_create.yaml`, RSVP via seeded event |
| CAL-008 | **partial** | `features/calendar_event_cover.yaml` (picker only) |
| REG-001–002,005 | **automated** | `registry_crud.yaml`, `registry_mark_purchased.yaml` |
| REG-004 | **automated** | `roles/registry_claim_follower.yaml` |
| ACC-001 | **automated** | `subflows/open_account.yaml` / settings flows |
| ACC-004 | **automated** | `features/account_settings.yaml` |
| ACC-005 | **manual** | Export job + worker + download (long; DLQ BE-001) |
| ACC-006 | **automated** | `destructive/account_delete_throwaway.yaml` |
| ACC-007 | **manual** | Co-owner delete account |
| ACC-008 | **partial** | `followers_invite.yaml`, `followers_revoke_remove.yaml` |
| NOT-001–003 | **partial** | `smoke/open_notifications.yaml`, `features/notifications_inbox_read.yaml` |
| NOT-005–007 | **manual** | Push/deep link/FCM payload — MULTI-001 |
| VER-001 | **implicit** | App launch in every flow |
| VER-002 | **manual** | Force-update block — DB version bump |
| OFF-001 | **automated** | `smoke/offline_banner.yaml` |
| OFF-002 | **partial** | `smoke/pull_to_refresh_account.yaml` |
| DL-001–003 | **partial** | Covered indirectly; no dedicated deep-link matrix |
| BE-001–003,006,010 | **manual** | GCP / worker / migration gates |

## CI

Workflow [`.github/workflows/e2e-smoke.yml`](../../.github/workflows/e2e-smoke.yml) runs `--smoke` on `pull_request` when required secrets are configured; otherwise the job is **skipped** (not failed).

### GitHub Actions secrets (names only)

- `SMOKE_TEST_PASSWORD`
- `FOLLOWER_TEST_PASSWORD` (optional if same as smoke)
- `DB_PASSWORD`
- `APP_CHECK_DEBUG_TOKEN` (optional but recommended)

Store emails as repository **variables** if desired (`SMOKE_TEST_EMAIL`, `FOLLOWER_TEST_EMAIL`); defaults match `local.env.example`.

## Semantics

Stable selectors use `AppSemantics` / `semanticsId` in shared widgets. Convention: `auth_*`, `shell_*`, `settings_*`, `invite_landing_*`, `offline_banner`, etc. See [`apps/mobile/maestro/README.md`](../../apps/mobile/maestro/README.md).

## Risks / limitations

- **Not executed in cloud agent VMs** — flows are authored against the codebase only; validate on a local emulator before merge.
- **Email and push** — AUTH-002, AUTH-006, NOT-006/007, MULTI-001 remain manual by design.
- **Biometrics** — BIO-002–006 need emulator fingerprint enrollment; often skipped in CI.
- **Media uploads** — Gallery/cover flows open pickers; full GCS pipeline relies on API integration tests + BE-002.
- **Public repo** — never commit passwords; use env files or CI secrets only.
- **Data** — destructive flows create throwaway Firebase/SQL users; smoke accounts are reprovisioned via `provision_maestro_fixtures.py`.
