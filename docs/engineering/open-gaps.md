# Open gaps (pre-beta)

Pending items from the Oct 2026 full-stack review. Completed items were removed; see git history for the original audit.

**Legend:** **Verified** — confirmed in code; **Reported** — from review pass, not re-read.

Related: [pre-beta-qa.md](pre-beta-qa.md), [development.md](development.md), [operations.md](operations.md).

---

## Summary

| Severity | Open | Themes |
|----------|------|--------|
| High | 4 | Release signing, worker OIDC, App Check enforce, admin surface |
| Medium | 10 | Rate limits, worker hardening, infra/IAM/prod parity, App Check client, biometrics, CI |
| Low | 7 | Release config, a11y/i18n, CORS, observability, Docker/CI hygiene |

---

## High

### H-01 Android release is signed with debug keys — Verified
- **Where:** `apps/mobile/android/app/build.gradle.kts` (release `signingConfig = signingConfigs.getByName("debug")`)
- **Issue:** Release APK/AAB uses the debug keystore (TODO left in file). Not acceptable for Play upload or any distribution you intend to update in place.
- **Fix:** Add an upload keystore + `signingConfigs.release` read from `key.properties` / CI secrets; keep debug signing only for local `flutter run --release`.

### H-04 Worker `/pubsub/push` has no in-app OIDC verification — Verified (grep) / Reported (impact)
- **Where:** `services/worker/src/lanonna_worker/main.py` (push + cron routes); no `Authorization` / OIDC verification anywhere in `services/worker/src`
- **Issue:** Security rests entirely on Cloud Run `run.invoker`. Any principal granted invoker can POST arbitrary payloads (notify, export, invite email). Docs describe OIDC push but the app does not validate the token. Cron HTTP routes are likewise unauthenticated at the app layer.
- **Fix:** Verify Google OIDC JWT (audience = worker URL; expected push/scheduler service account email). Remove HTTP cron routes if Scheduler uses Pub/Sub only.

### H-05 App Check not enforced by default — Verified (config/deploy)
- **Where:** `services/api/src/lanonna_api/config.py` (`app_check_enforce = False`); `services/api/scripts/deploy.sh` (`APP_CHECK_ENFORCE` defaults `false`, TEMP note)
- **Issue:** NFR-SEC-002 requires enforcement before public beta. With enforce off, missing/invalid App Check tokens are only logged. Combined with `--allow-unauthenticated`, JWT is the only gate.
- **Fix:** Enable for beta/prod (`APP_CHECK_ENFORCE=true`), keep dev override documented, ensure debug tokens are registered for QA devices. *(Intentional off on dev until beta.)*

### H-06 Admin CRUD on public Cloud Run with a single static key — Reported
- **Where:** `services/api/scripts/deploy.sh` (`--allow-unauthenticated`), `admin_auth.py`, `routers/admin_system_announcements.py`
- **Issue:** `/v1/admin/system-announcements` protected only by `X-Admin-Key`; no rate limit, no IP/IAM restriction; comparison is `!=` (not constant-time).
- **Fix:** `secrets.compare_digest`; rate-limit admin paths; consider IAP/IAM or a private admin surface; rotate key via Secret Manager.

---

## Medium

### API

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-09 | Rate limiting only on photo init and batch invite; per-instance buckets | `middleware/rate_limit.py` | Edge limiter for preview/admin; document scaling caveat |

### Worker / data

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-15 | Thumbnail download loads whole object in memory, no size/dimension cap | `worker/thumbnails.py` | Cap bytes/dimensions |
| M-16 | Worker config defaults to dev project/buckets if env unset | `worker/config.py` | Fail fast outside dev |

### Infra

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-19 | Prod env lacks push-subscription / Cloud Build wiring present in dev; dev hardcodes worker URL; Run invoker IAM is script-managed, not Terraform | `environments/prod/main.tf`, `dev/main.tf`, `run_iam.tf` | Parameterize endpoint; manage invoker in TF |
| M-20 | Secret accessor granted to API and worker for all secrets (incl. `admin-api-key`) | `modules/platform/iam.tf` | Per-secret bindings |
| M-21 | Dev automation SA has `editor`, `serviceAccountAdmin`, `projectIamAdmin` | `iam.tf` | Keep dev-only; narrow roles |
| M-22 | Cloud SQL public IPv4 enabled, no private IP / VPC connector | `modules/platform/sql.tf` | Private IP or documented restriction |

### Mobile

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-27 | App Check token silently omitted when `getToken` fails | `core/app_check/app_check_bootstrap.dart`, `core/api/api_client.dart` | Retry/backoff or visible warning |
| M-31 | Biometric unlock (PRD §5.3) not implemented — no `local_auth` usage | n/a | Implement or mark deferred in PRD |

### CI / docs / process

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-32 | GitHub CI entirely commented out; README and package docs still describe CI on PRs; email-template `check` job also disabled | `.github/workflows/ci.yml`, `README.md`, `packages/email-templates/README.md` | Re-enable (add `httpx` for API tests) or update docs |

---

## Low

| ID | Issue | Where |
|----|-------|-------|
| L-07 | Default API base URL baked in source; release builds must use `--dart-define-from-file` | `config/app_config.dart` |
| L-08 | Accessibility: semantics labels concentrated in shell/onboarding; many controls unlabeled (WCAG AA is the PRD baseline) | mobile |
| L-09 | Hardcoded UI strings vs `app_en.arb` (FR-SET-002) | e.g. `account_edit_screen.dart`, `home_screen.dart` |
| L-10 | No CORS middleware (fine for mobile-only; needs policy if a web client is added) | `services/api/main.py` |
| L-14 | Poison/unknown Pub/Sub messages are logged and acked (204) with no metric | `worker/main.py` |
| L-15 | Dockerfiles run as root; Cloud Build only builds/pushes (no tests) | `services/*/Dockerfile`, `cloudbuild.yaml` |
| L-16 | Duplicate email template trees (intentional) but sync check is disabled with CI | `packages/email-templates`, `services/worker/email_templates` |

---

## Test coverage gaps (still thin)

- **API:** Router tests still thin or missing for `events`, `registry`, `fun`, `data_export`, `search`, `notifications`, `onboarding`, `admin_system_announcements`.
- **Mobile:** `delete_account_screen_test.dart` only checks copy (no eligibility/delete/sign-out flow); upload tests cover headers only; login test is UI-only.
- **Worker:** Add regression tests for export failure/reclaim and invite-email claim paths if not already covered on `main`.

---

## Suggested fix order

1. **Pre-beta security:** H-01, H-04, H-05, H-06, M-27
2. **Infra + prod parity:** M-19–M-22
3. **Ops / scale:** M-09, M-15, M-16, M-32, L-14–L-16
4. **Product / polish:** M-31, L-07–L-10
