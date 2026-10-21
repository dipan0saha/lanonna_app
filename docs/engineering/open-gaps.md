# Open gaps (pre-beta)

Open engineering gaps for La Nonna. Seeded from the Oct 2026 full-stack review and extended by a second full code review on **2026-10-11** (API, data layer, worker, mobile, infra/docs), live test runs, and the **2026-10-16** architecture review of the fix stream (see below).

**Legend:** **✅** = resolved in repo **or** accepted intentional dev decision ([intentional-dev-decisions.md](intentional-dev-decisions.md)); entry kept for audit. **Verified** — gap confirmed by code/tests; **Reported** — suspected, not fully traced.

Related: [pre-beta-qa.md](pre-beta-qa.md), [development.md](development.md), [operations.md](operations.md), [intentional-dev-decisions.md](intentional-dev-decisions.md).

**Note (2026-10-17):** Global baby-scoped search (`/search`, `GET …/search`) was removed from mobile and API; historical ✅ entries below that mention search remain for audit.

---

## Health snapshot (2026-10-17)

| Check | Result |
|-------|--------|
| API `pytest` (`services/api`, unit + Postgres integration) | 315 passed (plus 9 in `packages/lanonna_activity_copy/tests`) |
| Worker `pytest` | 97 passed (`tests/test_pubsub_terraform.py` asserts live `pubsub.tf` retry policy) |
| `flutter test` (`--exclude-tags golden` in CI) | 436 passed |
| `flutter analyze` | 0 errors, 0 warnings; infos do not fail CI (`--no-fatal-infos`, L-26) |
| l10n guard (`tool/check_hardcoded_user_strings.dart`) | 0 violations; allowlist entries all carry a justification |

Run all three suites before every ship. GitHub Actions CI ([`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)) runs them on every pull request and push to `main` (Flutter 3.38.9 pinned; macOS-rendered goldens excluded on Linux). Merge only with CI green.

---

## Summary

| Severity | Open | Themes |
|----------|------|--------|
| High | 3 | Release signing, worker OIDC, App Check enforce |
| Medium | 12 | Export memory limits (beta), mobile error/async/date handling (infra prod-wiring M-19/M-47/M-50/M-52 addressed in repo) |
| Low | 10 | Accessibility, infra GCS, Docker, lint remainder, deferred consolidation backlog |

---

## High

### H-01 Android release signing — Partial (dev vs prod)
- **Where:** `apps/mobile/android/app/build.gradle.kts`, `android/key.properties` (gitignored)
- **Issue:** Play upload requires an upload keystore, not the debug key.
- **Status:** **Prod** release (`APP_ENV=prod`) fails Gradle configure without `key.properties`. **Dev** release may still use the debug keystore when `key.properties` is absent (local testing). Owner must create the upload keystore and `key.properties` before the first prod ship — [android/README.md](../../apps/mobile/android/README.md), [mobile-prod-flavor-and-crashlytics.md](mobile-prod-flavor-and-crashlytics.md).

### ✅ H-03 Account delete must tombstone SQL before Firebase — Verified
- **Where:** `services/api/src/lanonna_api/domain/account_delete.py`, `repositories/account_delete.py`
- **Issue:** Deleting the Firebase user before the SQL tombstone (or without idempotent retry) could strand auth vs `app_users` state.
- **Fix:** Soft-delete in SQL first, then `delete_user`; retry POST skips SQL when already tombstoned.
- **Status:** ✅ Fixed

### H-04 Worker `/pubsub/push` has no in-app OIDC verification — Verified (grep) / Reported (impact)
- **Where:** `services/worker/src/lanonna_worker/main.py` (push + cron routes); no `Authorization` / OIDC verification anywhere in `services/worker/src`
- **Issue:** Security rests entirely on Cloud Run `run.invoker`. Any principal granted invoker can POST arbitrary payloads (notify, export, invite email). Docs describe OIDC push but the app does not validate the token. Cron HTTP routes are likewise unauthenticated at the app layer.
- **Fix:** Verify Google OIDC JWT (audience = worker URL; expected push/scheduler service account email). Remove HTTP cron routes if Scheduler uses Pub/Sub only.

### H-05 App Check not enforced by default — Verified (config/deploy)
- **Where:** `services/api/src/lanonna_api/config.py` (`app_check_enforce = False`); `services/api/scripts/deploy.sh` (`APP_CHECK_ENFORCE` defaults `false`, TEMP note)
- **Issue:** NFR-SEC-002 requires enforcement before public beta. With enforce off, missing/invalid App Check tokens are only logged. Combined with `--allow-unauthenticated`, JWT is the only gate.
- **Fix:** Enable for beta/prod (`APP_CHECK_ENFORCE=true`), keep dev override documented, ensure debug tokens are registered for QA devices. **Dev Android:** optional pinned UUID in `maestro/local.env` (`APP_CHECK_DEBUG_TOKEN`) + [`register-app-check-debug.sh`](../../apps/mobile/maestro/scripts/register-app-check-debug.sh) + debug rebuild (`LanonnaApplication` seeds Firebase debug prefs). *(Intentional off on dev until beta.)*

### ✅ H-06 Admin CRUD on public Cloud Run with a single static key — Reported
- **Where:** `services/api/scripts/deploy.sh` (`--allow-unauthenticated`), `admin_auth.py`, `routers/admin_system_announcements.py`
- **Issue:** `/v1/admin/system-announcements` protected only by `X-Admin-Key`; no rate limit, no IP/IAM restriction; comparison is `!=` (not constant-time).
- **Fix:** `secrets.compare_digest`; rate-limit admin paths; consider IAP/IAM or a private admin surface; rotate key via Secret Manager.
- **Status:** ✅ Intentional for `lanonna-dev` — see [intentional-dev-decisions.md](intentional-dev-decisions.md#h-06).

### ✅ H-09 Export Pub/Sub dedupe drops the retries that recovery depends on — Verified
- **Where:** `services/worker/src/lanonna_worker/main.py`, `baby_data_export.py`
- **Issue:** `messageId` delivery dedupe committed before export ran, so Pub/Sub redeliveries were acked without retrying failed/stale-`running` jobs.
- **Fix:** Drop export message-id dedupe; use job row + `deliveryAttempt`-aware claim/failure and stale-`running` takeover.
- **Status:** ✅ Fixed

### ✅ H-10 Baby search fails: queries a non-existent column — Verified
- **Where:** `services/api/src/lanonna_api/repositories/search.py`; migration `004` (`suggested_name`)
- **Issue:** Name-suggestion leg of baby search referenced column `name` instead of `suggested_name`.
- **Fix:** Query `suggested_name AS name` with `suggested_name ILIKE`; repository test added.
- **Status:** ✅ Fixed

### ✅ H-11 Sign-out and account delete leave cross-user local state — Verified
- **Where:** `core/auth/session_cleanup.dart`, account/delete screens, `user_deleted_session_handler.dart`, `home_repository.dart`
- **Issue:** Sign-out left invite preview, selected baby, home cache, onboarding drafts, and signed-image disk cache on shared devices.
- **Fix:** `SessionCleanup` on every sign-out path; uid-scoped home cache with safe offline fallback.
- **Status:** ✅ Fixed

### ✅ H-12 Photo-ready notification lost if fan-out fails after the claim — Verified
- **Where:** `services/worker/src/lanonna_worker/thumbnails.py`, `idempotency.py`
- **Issue:** Pre-claim committed before fan-out; retries skipped notify permanently after a transient failure.
- **Fix:** Idempotency via fan-out `dedupe_key` in the same transaction; removed pre-claim.
- **Status:** ✅ Fixed

### ✅ H-13 Dead-letter topic has no subscription — Verified
- **Where:** `infra/terraform/modules/platform/pubsub.tf`
- **Issue:** DLQ topic had no pull subscription; dead-lettered messages were not retained for inspection/replay.
- **Fix:** DLQ pull subscription (7-day retention) and subscriber IAM; documented in operations.
- **Status:** ✅ Fixed

### ✅ H-14 iOS camera/photo-library usage descriptions are missing — Verified
- **Where:** `apps/mobile/ios/Runner/Info.plist`; `image_picker` in onboarding and profile flows
- **Issue:** Missing usage keys crash camera/library on iOS and block App Store review.
- **Fix:** `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`.
- **Status:** ✅ Fixed

### ✅ H-15 Gallery silently truncates after 50 photos — Verified
- **Where:** `gallery_repository.dart`, `gallery_screen.dart`; API `routers/photos.py` (`limit`/`offset`)
- **Issue:** Default API page size hid photos beyond 50 with no UI signal.
- **Fix:** `listPhotosPage`, infinite scroll, end-of-list copy; `listPhotos()` loads all pages for pickers.
- **Status:** ✅ Fixed

---

## Medium

### API

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| ✅ M-02 | Co-owner accept race: two concurrent accepts could exceed two owners | `repositories/invitations.py`, `memberships.py` | Row lock baby profile before owner count (see **M-36**) |
| M-09 | Rate limiting only on photo init and batch invite; per-instance buckets | `middleware/rate_limit.py` | Edge limiter for preview/admin; document scaling caveat |
| ✅ M-36 | Co-owner accept race (M-02 reopened): `lock_baby_profile_for_update` not called before `count_active_owners` | `repositories/invitations.py`, `repositories/memberships.py` | Lock baby row inside accept transaction; race tests green |
| ✅ M-37 | Ended (removed) members get **500** instead of `403 membership_ended` on search, invitation owner routes, members list, and first-moment seed | `routers/search.py`, `invitations.py`, `members.py`, `babies.py` | Routers use `except Exception` + `map_domain_errors`; `test_router_membership_ended.py` |
| ✅ M-38 | Concurrent registry purchase claims: check-then-insert race on `registry_item_id` unique | `domain/registry.py`, `repositories/registry.py` | `ON CONFLICT DO NOTHING RETURNING`; loser gets `PermissionError` (403), no 500 |
| ✅ M-39 | Fun: non-atomic like toggle, racy follower name cap, N+1 `user_has_like` in `list_names` | `domain/fun.py`, `repositories/fun.py`, `memberships.py` | Single-transaction `toggle_like`; locked follower suggest; `liked_suggestion_id_set` |
| ✅ M-40 | Photo `tagged_babies` join ignores `removed_at` and `deleted_at` | `repositories/photo_tags.py` | Filter `m.removed_at IS NULL` and `b.deleted_at IS NULL` in tag list SQL |

### Worker / data

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| ✅ M-11 | Export jobs: stale `running`, missing failure path, retry not wired to Pub/Sub | `worker/baby_data_export.py`, migrations `026` | `started_at`, reclaim stale runs, mark failed; pairs with **H-09** |
| ✅ M-12 | Duplicate Pub/Sub invite deliveries could double-send email | `worker/invite_email.py`, migration `027` | Claim invite send in DB before Mailjet |
| ✅ M-63 | Transient Mailjet/network errors left invites without resend path; delivery state opaque | `worker/invite_email.py`, migration `034`, `invitations` domain/API (#62) | `email_delivery_status` / `email_send_attempts`; HTTP **500** retries via Pub/Sub; **resend** + undelivered duplicate resend; DLQ alert in `monitoring.tf`. In-process `time.sleep` retries removed (#322): `InviteSendOutcome.RETRY` → 500 and Pub/Sub backoff is the only retry |
| ✅ M-15 | Thumbnail download loads whole object in memory, no size/dimension cap | `worker/thumbnails.py` | `MAX_DISPLAY_BYTES` / pixel cap; skip oversize or decompression bombs |
| ✅ M-16 | Worker config defaults to dev project/buckets if env unset | `worker/config.py` | `validate_worker_settings()` at startup; non-dev rejects dev defaults |
| ✅ M-41 | Raw `invite_token` on Pub/Sub + full payload logging | `api/pubsub.py`, `worker/main.py`, migration `028` | Publish `invitation_id` only; `email_invite_token` in DB until send; safe payload summary in logs |
| ✅ M-42 | Invite HTML email interpolated user fields unescaped | `worker/invite_email_copy.py`, `worker/invite_email.py` | `html.escape()` on HTML paths; tests |
| ✅ M-43 | Export: stale reclaim vs slow run; orphan GCS on failed finalize | `worker/baby_data_export.py` | `started_at` heartbeat during export; delete blob on failed finalize / lost `ready` claim (in-memory JSON at 512 Mi remains a beta limit — stream later if needed) |
| ✅ M-44 | Weekly digest deleted FCM tokens on any failure; no 500-token chunking | `worker/notifications.py` | Shared `_send_multicast_and_prune_tokens`; `_should_delete_fcm_token` |
| ✅ M-45 | Pub/Sub ack 120 s vs Cloud Run 300 s default | `pubsub.tf`, `worker/scripts/deploy.sh` | Push subs `ack_deadline_seconds = 300`; worker `--timeout=300` |
| ✅ M-46 | Permanent bad Pub/Sub payloads retried to DLQ | `worker/pubsub_payload.py`, `worker/main.py` | Decode/validate; ack 204 with `pubsub_payload_permanent_reject` logs |

### Infra

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| ✅ M-17 | Migration set drift: `023` not tracked; export/invite schema needed follow-on migrations | `infra/db/migrations/025`–`027` | Track `023`; add export `started_at` and invite send-claim columns |
| ✅ M-18 | Pub/Sub push had no dead-letter path; pull worker path obsolete | `infra/terraform/modules/platform/pubsub.tf` | Dead-letter policy on push subs; push-only worker; DLQ pull sub (**H-13**) |
| ✅ M-19 | Prod env lacks push-subscription / Cloud Build wiring present in dev; Run invoker IAM still reconciled via script after worker deploy | `environments/prod/main.tf`, `dev/main.tf`, `run_iam.tf`, `worker_push.tf`, [operations.md](operations.md) | **Dev:** ✅ push URL from live Cloud Run on `terraform apply` + invoker in TF; run `./scripts/apply-run-iam.sh` after worker deploy. **Prod:** two-phase apply documented (`terraform.tfvars.example` + operations); `cloudbuild.googleapis.com` on prod APIs. **Status:** ✅ Repo/runbook (project creation still manual). |
| ✅ M-20 | Secret accessor granted to API and worker for all secrets (incl. `admin-api-key`) | `modules/platform/iam.tf` | Per-secret bindings — **intentional on dev** ([intentional-dev-decisions.md](intentional-dev-decisions.md#m-20)) |
| ✅ M-21 | Dev automation SA has `editor`, `serviceAccountAdmin`, `projectIamAdmin` | `iam.tf` | Keep dev-only; narrow roles — **intentional on dev** ([intentional-dev-decisions.md](intentional-dev-decisions.md#m-21)) |
| M-22 | Cloud SQL public IPv4 enabled, no private IP / VPC connector | `modules/platform/sql.tf` | Private IP or documented restriction |
| ✅ M-47 | Prod Terraform sets the SQL app password (`manage_sql_app_password = true`) but never writes it to Secret Manager; Cloud Run reads `db-lanonna-app-password:latest`, so a fresh prod apply can leave API/worker unable to connect | `modules/platform/sql_secrets.tf`, `environments/prod/main.tf` | When `manage_sql_app_password=true`, TF writes `db-lanonna-app-password` version; dev keeps `false` so passwords are not rotated. **Status:** ✅ Fixed |
| M-60 | Prod SQL app password is generated in Terraform (`random_password`) and stored in **Terraform state** (and briefly in plan output) | `modules/platform/sql.tf`, `sql_secrets.tf`, state bucket | **Mitigation today:** restrict `gs://*-terraform-state` access, encryption at rest, no state in git. **Cleaner later:** generate password outside TF (`openssl rand`, `gcloud secrets versions add`) and import SQL user + secret version without `random_password` in state. See [rca/repo-email-scrub-and-hosting-iam.md](rca/repo-email-scrub-and-hosting-iam.md). |
| ✅ M-61 | Legacy Secret Manager secret **`database-url`** (monolithic Postgres URL) was unused; Cloud Run uses `DB_*` + `db-lanonna-app-password` | GCP `lanonna-dev`, `variables.tf` `secret_ids` | Removed from Terraform `secret_ids` and `import-dev.sh`; secret deleted in GCP. **Status:** ✅ resolved |
| ✅ M-48 | No repo-root `.gcloudignore`/`.dockerignore`; deploys uploaded the whole monorepo; service-level `.dockerignore` was ignored with repo-root context | repo-root `.gcloudignore`, `.dockerignore`; `services/*/scripts/deploy.sh` | Whitelist `packages/` + `services/`; removed `services/api/.dockerignore` and `services/worker/.dockerignore` |
| M-49 | Dev Cloud SQL has no deletion protection (`deletion_protection = var.environment == "prod"`) and no `prevent_destroy` | `modules/platform/sql.tf:30` | Enable for dev or add `lifecycle { prevent_destroy }` |
| ✅ M-50 | Worker FCM permission (`roles/firebasecloudmessaging.admin`) is documented but not in Terraform; a fresh environment silently fails to push | `modules/platform/iam.tf`, [operations.md](operations.md) | `worker_firebase_cloud_messaging_admin` binding; dev import documented. **Status:** ✅ Fixed |
| M-51 | `run-beta-gate.sh` needs `services/api/.venv` and deploys API only (no worker/IAM) | `scripts/run-beta-gate.sh:11-21` | Reuse the `verify-dev-prerequisites.sh` venv pattern; match the documented deploy order |
| ✅ M-52 | Deploy scripts hardcode `ENVIRONMENT=dev` even if `GCP_PROJECT_ID` points elsewhere | `scripts/lib/env.sh`, `services/*/scripts/deploy.sh`, `infra/env/prod.*.env` | Derive `ENVIRONMENT` from project id; load per-env files. **Status:** ✅ Fixed |
| ✅ M-53 | Dev maintenance scripts are unsafe: `clear_dev_test_data.py --email` hard-deletes **every** baby the user has any membership row for (including followed and tombstoned) and fails on `votes` FK; no environment guard on `--email`/`hard_delete_user`; `hard_delete_user.py` inits Firebase with the default ADC project | `infra/db/clear_dev_test_data.py:36-44,89-97,122-160`, `infra/db/hard_delete_user.py:523,531-544` | Limit to active, sole-owned babies; delete `votes`; require an explicit dev env/project guard — **intentional; operator discipline** ([intentional-dev-decisions.md](intentional-dev-decisions.md#m-53)) |

### Mobile

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-27 | App Check token silently omitted when `getToken` fails | `core/app_check/app_check_bootstrap.dart`, `core/api/api_client.dart` | **Partial (2026-10-16):** debug bootstrap retries `getToken` and logs register/pin hints; `AppCheckTokenSource` bounds each read at 10 s; API client still omits `X-Firebase-AppCheck` on failure |
| ✅ M-31 | Biometric unlock (PRD §5.3) | `local_auth`, `BiometricAppLock`, migration `035` | Profile flag + settings toggle + resume/cold-start lock overlay; `BiometricAppLock` uses injected `GoRouter` ([rca/biometric-app-lock-never-engages.md](rca/biometric-app-lock-never-engages.md)) — **Status:** ✅ Fixed |
| ✅ M-54 | Invite-mismatch PII in GoRouter query strings; invitee email in persisted preview JSON; Android Auto Backup of prefs | `InviteFlowState`, `invite_flow_navigation.dart`, `onboarding_wrong_email_screen.dart`, `AndroidManifest.xml` | In-memory mismatch/prefill/resume; preview JSON omits `invitee_email`; `allowBackup=false` + `backup_rules.xml` |
| ✅ M-55 | Signed-in invite accept screens show `e.toString()` of an `Exception` instead of mapped copy | `onboarding_follower_invite_screen.dart`, `onboarding_coowner_invite_screen.dart`, `invite_accept_messages.dart` | Shared `inviteLandingAcceptErrorMessage` (`apiErrorMessage` / generic `Exception` strip) — **Status:** ✅ Fixed (2026-10-14) |
| M-56 | `AppSession.refreshFromApi` swallows all errors (`catch (_)`), so a failed status fetch can misroute (onboarding vs home) with no feedback | `onboarding/presentation/app_session.dart:46-57` | Surface an error/retry state or redirect conservatively |
| M-57 | Non-debug builds built with `MAESTRO_SEMANTICS=true` use the App Check debug provider and log the debug token | `core/app_check/app_check_bootstrap.dart:4-27`, `main.dart:18-24` | Restrict the debug provider to `kDebugMode`; guard token logging |
| ✅ M-58 | Announcement screens: `_load`/`_prefill` have no error handling (permanent spinner on failure); squish/comment failures are unhandled; four `TextEditingController`s never disposed | `announcement/presentation/announcement_card_screen.dart:42-72`, `announcement_create_screen.dart:34-77` | try/catch/finally with `apiErrorMessage` + `AppSnackBar`; dispose controllers — **Status:** ✅ Fixed (2026-10-14) |
| M-59 | Async hygiene: no `mounted` check before `setState` after awaits (gallery, home, names tab); registry delete bypasses `runMutation`; gallery upload polling ends silently after ~24 s | `gallery_screen.dart:114-132,178-196`, `home_screen.dart:85-103`, `names_tab.dart:54-58`, `registry_screen.dart:298-303` | Guard with `mounted`; show errors; use `runMutation`; surface poll timeout — **partial ✅** (2026-10-14): registry delete + gallery poll timeout; global search error surfacing was already fixed; home/names `mounted` guards still open |
| ✅ M-60 | Date handling violates the documented UTC-in/local-out rule: photo `created_at` formatted in UTC (wrong day for evening uploads); date-only API fields parsed with `DateTime.tryParse` instead of `tryParseApiCalendarDate` | `gallery/data/models/photo_models.dart:27`, `photo_detail_screen.dart:399,659-664`, `home_screen.dart:123-130`, `announcement_create_screen.dart:63-65` | Use `parseApiInstant` / `tryParseApiCalendarDate` helpers — **Status:** ✅ Fixed (2026-10-14) |
| ✅ M-61 | Event form has no owner guard (followers reaching the route see a full form that fails on save); cover thumbnail lacks `onSignedUrlError` so it breaks after the 900 s URL TTL | `calendar/presentation/event_form_screen.dart:106-116,413-418`, `widgets/event_form_widgets.dart:43-48` | Gate by role; pass a refresh callback — **Status:** ✅ Fixed (2026-10-14) |

### Tests

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| ✅ M-62 | Test suite red after review: invitation accept race, stale onboarding mock, Flutter harness missing providers | `test_invitation_accept_race.py`, `test_onboarding_domain.py`, mobile widget tests | Fix **M-36**; update mocks; add `ConnectivityService` / notification fakes |

---

## Low

| ID | Issue | Where |
|----|-------|-------|
| ✅ L-07 | Default API base URL baked in source; release builds must use `--dart-define-from-file` | `app_config.dart` — const `String.fromEnvironment('API_BASE_URL')`; release/profile compilation fails with a const integer-division error when it is empty (asserts are stripped from those builds). Debug omits the define and uses the dev URL. |
| L-08 | Accessibility: icon-only `IconButton`s go through `AppIconButton` (required label). Subpage Back, calendar and prediction month arrows, home photo thumbnails, tappable activity rows, registry edit/delete/add, name love/remove, notification rows, and password show/hide are labeled (#49). Other controls can still be unlabeled (WCAG AA is the PRD baseline) | mobile |
| ✅ L-09 | Hardcoded UI strings vs `app_en.arb` (FR-SET-002) | **Fixed (2026-10-16, #322–#325):** all client copy (screens, validators, domain failures, link sentences) moved to ARB; sink-agnostic AST guard `tool/check_hardcoded_user_strings.dart` runs in CI with a justified allowlist |
| ✅ L-10 | No CORS middleware (fine for mobile-only; needs policy if a web client is added) | `main.py`, `config.py` — `CORS_ALLOW_ORIGINS` comma-list; off when empty |
| L-14 | Poison/unknown Pub/Sub messages are logged and acked (204) with no metric; permanent rejects log `pubsub_payload_permanent_reject` (**M-46**). DLQ depth has a Monitoring alert policy in `monitoring.tf` (#62); wire a notification channel in Cloud Console. | `worker/main.py`, `worker/pubsub_payload.py`, `modules/platform/pubsub.tf`, `modules/platform/monitoring.tf` |
| L-15 | Dockerfiles run as root; Cloud Build only builds/pushes (no tests); base images use floating `python:3.12-slim` tags | `services/*/Dockerfile`, `cloudbuild.yaml` |
| L-16 | Duplicate email template trees (intentional); run `scripts/sync-email-templates.sh check` locally before commit | `packages/email-templates`, `services/worker/email_templates` |
| ✅ L-17 | Unbounded inputs on PATCH/list routes | `input_limits.py` + router `Field(max_length=…)` on photos, fun, events, registry, invitations |
| ✅ L-18 | Search `q` is not escaped for `ILIKE` wildcards (`%`, `_`); `PermissionError` returned plain string `detail` | `text_ilike.py`, `repositories/search.py`, `http_errors.py` — `ilike_substring_pattern` + `ESCAPE '\'`; `PermissionError` → `{error,message}` |
| ✅ L-19 | Calendar `list_events` unbounded; storage usage counted soft-deleted babies | `events.py` `LIST_EVENTS_MAX_ROWS`; `user_engagement.py` joins `baby_profiles.deleted_at` |
| ✅ L-20 | Dead config: API `invite_deep_link_base` was unused (worker-only) | `services/api/config.py` — removed from API `Settings` |
| ✅ L-21 | Worker hygiene: export `SELECT *` / silent activity cap; unknown Pub/Sub payloads logged in full | `worker/export/collect.py` — explicit column lists, `export_activity_truncated` when activity exceeds `ACTIVITY_EXPORT_MAX_ROWS` (500); `worker/main.py` — `_safe_payload_summary` + unknown-type log (type/keys only; **M-41**) |
| L-22 | Infra hygiene: GCS buckets lack `public_access_prevention`/versioning/lifecycle (**open**); `import-dev.sh` omitted `admin-api-key` | `storage.tf` — **fixed:** `admin-api-key` in `import-dev.sh` secret loop |
| ✅ L-23 | Docs drift: mobile module table, `/health`, migration verify path | `development.md`, `operations.md` |
| ✅ L-24 | Android release R8/minify; FCM unregister / router refresh hygiene | `android/app/build.gradle.kts`, `proguard-rules.pro`; `push_notification_service.dart`, `router_refresh.dart` |
| ✅ L-25 | Mobile convention: hex colors, ARB strings, `runMutation`, count/plural hygiene | `AppColors` tokens; `app_en.arb`; batch invite, wrong-email, gallery semantics, fun/account counts |
| L-26 | `flutter analyze` infos — `use_null_aware_elements`, `unnecessary_underscores`, deprecated form `value` (**partial:** login/signup `mounted` guards; `home_repository` null-aware map) | mobile `lib/`, `test/` |
| ✅ L-27 | Legacy `photo_ready_notification_log` unused after fan-out `dedupe_key` | migration `029` — `DROP TABLE photo_ready_notification_log` |
| ✅ L-29 | Server-written error messages (`detail.message`) were English only and the app showed them verbatim when it had no mapping for `detail.error` | **Fixed (2026-10-16):** `domain/errors.py` `ErrorCode` + typed `DomainError` subclasses; every HTTP error (domain, `HTTPException`, 404/405, 422, 429, 500) is `{error, message[, params]}` via `http_errors` + `main.py` handlers; app `ApiErrorCode` (`core/api/api_error_code.dart`) maps codes to ARB copy in `apiErrorMessage`, server text is diagnostics only; `test_error_code_parity.py` keeps the Python/Dart enums in sync |
| ✅ L-30 | Batch invites validated each row with its own queries | **Fixed (2026-10-16):** `repositories/invitations.py` `load_invite_targets` (one `unnest` query for members + pending invites) and `write_batch_invitations` (resends + inserts in one transaction, `ON CONFLICT … DO NOTHING` on the pending-invite index); typed `InviteRowStatus` per row; emails enqueued after commit; Postgres integration test `test_batch_invite_postgres.py` |
| ✅ L-31 | Weekly digest looked up FCM tokens one user at a time | **Fixed (2026-10-16):** digest query aggregates tokens with a `LATERAL` join; inbox/push fan-out and notify-user share `_load_recipients` (one query for prefs + tokens), one `unnest` notification insert and one stale-token delete; Postgres integration test `test_notification_delivery_postgres.py` |
| ✅ L-32 | Notification and activity text was English built on the server (`title` / `body` / `summary`), names defaulted to English in SQL and Python ("Family member", "Someone", "Baby", "A family member"), the app bolded the actor with a `startsWith` heuristic, RSVP status and gender guesses showed raw API values, the photo-ready push had no type or actor, and the worker derived the photo actor from the email local part | **Fixed (2026-10-17):** shared vocabulary `packages/lanonna_activity_copy` (`NotificationKind`, `ActivityEventType`, param keys, `push_copy`); publishers send `kind` + `params` (`FanOutSpec` / `NotifyUserSpec`), activity rows store `params` (migration `038`, backfilled from structured sources); names are `null` when unset and the app applies `personDisplayName` / `babyDisplayName`; the app renders every inbox and activity sentence from ARB (`inboxSentence`, `activitySentence`, `PlaceholderRichText` for bold names); push copy stays server-side by design (OS-rendered); `test_feed_vocabulary_parity.py` pins the Dart enums |
| ✅ L-33 | Max-owners limit enforced only at accept: batch invite created co-owner invites that could never be accepted | **Fixed (2026-10-17):** `domain/owner_limit.py` is the one rule; batch invite counts active owners plus pending unexpired owner invites under the baby row lock and returns `skipped_max_owners` per row (app alert `batchInviteMaxOwnersSkipped`); accept raises `MaxOwnersError` (typed `DomainError`, the accept router's private error table was removed); Postgres tests `test_owner_limit_postgres.py` |
| ✅ L-34 | Delete-account `allowed` / `blockers` were always `true` / `[]` and the app rendered blockers with a hardcoded bullet | **Fixed (2026-10-17):** deletion is never blocked (FR-SET-005), so the dead contract was removed: `GET /v1/me/delete-account/preview` returns `sole_owned_babies` only; app `DeleteAccountPreview`; bullets come from ARB (`deleteAccountSoleOwnedBaby`) and unnamed babies are listed as **Baby** instead of being dropped |
| ✅ L-35 | Members API returned `email` and `relationship_label` that no screen used (`MemberRow`) | **Fixed (2026-10-17):** removed from the members SQL, response and `MemberRow` (Manage followers shows name, role and joined date per the prototype) |
| ✅ L-36 | Create-baby revise hydration treated a stored name equal to the literal `'Baby'` as "no name" and switched on raw gender strings. Root cause: `POST /v1/babies` required a name and `baby_profiles.name` was `NOT NULL`, so the app filled a missing name with its localized display default before sending it and the default was persisted as data; gender had two "unknown" representations (`NULL` / `'unknown'`) and raw `'male'`/`'female'` comparisons in Fun, announcement, first-moment drafts and the avatar | **Fixed (2026-10-17):** the name is optional end to end — `BabyName` (`schemas/babies.py`, blank → `NULL`), `PATCH` clears the name on a blank value (`null` stays "unchanged", which older builds send), migration `039` drops `NOT NULL`, adds `CHECK (name IS NULL OR btrim(name) <> '')`, clears exactly-`'Baby'` / blank names and their snapshotted `baby_name` params, and makes `gender` `NOT NULL DEFAULT 'unknown'`; event params carry the name only when set (`baby_name_params`); invite email reads "their baby" when unnamed. App: `BabySummary.name` is `String?`, `gender` is `BabyGender`; every display goes through `babyNameLabel` ("Baby") or `babyDisplayName` ("your baby"); create sends no name and revise/edit send an empty one when the field is cleared — never a placeholder; `NameSuggestionDraft` and `BabyGender.tryFromApi` replace raw gender strings app-wide |
| ✅ L-37 | Event cover "Upload new photo" showed only the camera icon (#65 part 2). Root cause: the event form was the only photo form that uploaded inside the picker sheet instead of on Save; it stored the new photo id with no signed URL, and `PrototypeEventCoverUpload` could only draw a URL, so edit mode looked like the cover had been removed. The upload had no busy state, no error handling, and left orphan gallery photos when the form was cancelled. In the same path, "No cover photo" (and clearing description, location or video link) never saved in edit because `updateEvent` dropped null fields, and photo encoding ran on the UI isolate | **Fixed (2026-10-17):** shared `PhotoSelection` + `PhotoSelectionPreview` + `pickDisplayPhoto` used by every form photo slot (event cover, announcement, account and baby avatars, onboarding profile and first moment, create baby). The event cover previews the picked file at once and uploads on Save with a busy overlay and `apiErrorMessage`, and a failed save retries without re-uploading. `GalleryRepository.uploadPhoto` owns gallery uploads, and the upload API takes `XFile` (web `kIsWeb` skips removed). `updateEvent` sends explicit nulls. Encoding runs via `compute`. Tests: `event_form_cover_photo_test.dart`, `photo_selection_test.dart`, `calendar_repository_test.dart` |
| L-28 | **Consolidation backlog (deferred, medium risk — live request paths):** gallery vs calendar comment domain logic and photo/event comment SQL; router `try/except map_domain_errors` boilerplate; dynamic `UPDATE … SET` builders; mobile comment composer, tab empty states, AI-suggestions screen state machine, labeled-field shell, wider `runMutation` use; shared `get_connection` for API + worker, `infra/db` shared `connect()` and invite-hash helper; Terraform push-subscription `for_each` and dev/prod API-list dedupe; scheduler script merge; PUT/PATCH announcement alias. Request-scoped `upsert_app_user` calls were replaced by `current_app_user` (#36). | `services/api`, `apps/mobile`, `infra/` |

---

## Architecture review follow-ups (2026-10-16) — resolved

A review of the Oct 2026 fix stream (#45–#63, #317–#320, `8e084a3`) found patch-like or duplicated logic; all items were fixed at the root in #321–#325:

| Item | Fix |
|------|-----|
| ✅ Inbox type/actor inferred from English copy (#319) | Migrations `036` / `037`: `notification_type`, `actor_firebase_uid`, `actor_display_name`; worker writes them; app maps `InboxNotificationType` → icon; heuristics deleted |
| ✅ "Born" rule duplicated in the client; names writable after birth | `domain/fun_closed.py` (`FunWritesClosedError` → 409 `fun_closed` / `predictions_closed`); `names_closed` / `predictions_closed` on home summary, baby summaries and Fun payloads; Fun stays visible read-only |
| ✅ Past events capped at 30 with no paging; mixed list shapes | One `{items, offset, limit, has_more}` envelope (`pagination.py` / `offset_page.dart`), SQL paging with stable tiebreaks on every list route incl. calendar |
| ✅ Silent `catch (_)` on API calls; English `Exception` text | `apiErrorMessage(l10n, e)` + `AppSnackBar.showAlert`; `LocalizedFailure` for client domain failures; announcement fetch returns null only on 404 |
| ✅ `NotificationsUnreadSignal` side channel | `NotificationsRepository` is the `ChangeNotifier` (mark-read, mark-all-read, FCM foreground) |
| ✅ Worker in-process retries | Pub/Sub backoff only (M-63) |
| ✅ Raw API status strings in UI | Typed enums with `apiValue` / `fromApi` / `label(l10n)`; `RelationshipPreset` stores canonical labels |
| ✅ N+1 owner count per baby | `active_owner_count` subquery in the babies query; digest unread counts in one query; bulk photo-tag writes |
| ✅ Photo prev/next ignored grid sort; home cache dropped on baby switch; `AppUser` Mapping shim; silent `readInt` coercion | `?sort=` on photo detail route; per-baby home summary cache kept until sign-out; routers use `user.uid`; `readInt(strict:)` + debug log |

## Test coverage gaps (still thin)

- **API:** No router/HTTP tests for `fun`, `registry`, `invitations`, `notifications`, `search`, `admin_system_announcements`, baby photo routes, and `/v1/uploads/display/signed-url`; only domain-level mocks for `onboarding`. Event create/update time-range validation has an HTTP test. Repositories have almost no direct SQL tests (`search_name_suggestions` has a column-conformance test, and `tests/integration/` runs search, provisioning, and the onboarding gate on Postgres); also untested: `account`, `pubsub`, `storage`, `media_urls`, `membership`.
- **Mobile:** Untested core modules: `api_client`, `auth_repository`, `user_deleted_session_handler`, `push_notification_service`, `app_router`, `app_link_bootstrap`, `onboarding_storage`, `onboarding_coordinator`, `shell/`. No tests for `search/` (UI beyond error surfacing), `settings/` (UI), `legal/`, `home_activity_screen`, `calendar_upcoming_screen`, wrong-email and invite-bootstrap screens. Widget/unit coverage includes `app_chip`, onboarding carousel/icon blob, Google button, pill select, photo caption, biometric lock **policy** + [`biometric_app_lock_test.dart`](../../apps/mobile/test/biometric_app_lock_test.dart), `app_version_gate`, owner create-baby **revise** submit (`create_baby_submit_test.dart`), registry shipping models, and `#410` subpage scaffold insets (Oct 2026). `integration_test/` has only `home_summary_load_test.dart` and `smoke_sign_in_test.dart`. `session_cleanup_test.dart` covers local wipe on sign-out; `delete_account_screen_test.dart` only checks copy.
- **Worker:** Push routes now have poison-payload and export-dispatch tests (`test_main_pubsub_payload.py`, `test_main_export_dispatch.py`); invite HTML escaping, FCM chunking, and `pubsub_payload` have unit tests. Baby export SQL is covered by `services/api/tests/integration/test_baby_data_export_postgres.py` (real Postgres, including the baby-graph table manifest). Still thin: weekly digest, Mailjet claim-release edge cases. Lifecycle export tests stub the document builder.

---

## Suggested fix order

1. **Pre-beta security:** H-01, H-04, H-05, M-27, M-57
2. **Mobile correctness:** M-56, M-59 (remaining `mounted` guards), M-57
3. **Infra + prod parity:** M-19–M-22, M-47–M-52
4. **Ops / polish:** M-09, L-08, L-14–L-16, L-22, L-26; then the L-28 consolidation backlog
