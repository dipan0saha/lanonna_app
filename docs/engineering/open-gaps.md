# Open gaps (pre-beta)

Open engineering gaps for La Nonna. Seeded from the Oct 2026 full-stack review and extended by a second full code review on **2026-10-11** (API, data layer, worker, mobile, infra/docs) plus live test runs.

**Legend:** **✅** on an ID = fixed in repo (entry kept for audit); **Verified** — gap confirmed by code/tests; **Reported** — suspected, not fully traced.

Related: [pre-beta-qa.md](pre-beta-qa.md), [development.md](development.md), [operations.md](operations.md).

---

## Health snapshot (2026-10-11)

| Check | Result |
|-------|--------|
| API `pytest` (`services/api`) | 209 passed |
| Worker `pytest` | 56 passed |
| `flutter test` | 257 passed |
| `flutter analyze` | 0 errors, 0 warnings, 47 infos (L-26) |

Run all three suites before every ship; the suites are the only automated gate (no CI).

---

## Summary

| Severity | Open | Themes |
|----------|------|--------|
| High | 4 | Release signing, worker OIDC, App Check enforce, admin surface |
| Medium | 20 | Export memory limits (beta), infra/IAM/prod parity, mobile error/async/date handling |
| Low | 6 | Accessibility/i18n, infra GCS, Docker, lint remainder, deferred consolidation backlog |

---

## High

### H-01 Android release is signed with debug keys — Verified
- **Where:** `apps/mobile/android/app/build.gradle.kts` (release `signingConfig = signingConfigs.getByName("debug")`)
- **Issue:** Release APK/AAB uses the debug keystore (TODO left in file). Not acceptable for Play upload or any distribution you intend to update in place.
- **Fix:** Add an upload keystore + `signingConfigs.release` read from `key.properties` / release signing secrets; keep debug signing only for local `flutter run --release`.

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
- **Fix:** Enable for beta/prod (`APP_CHECK_ENFORCE=true`), keep dev override documented, ensure debug tokens are registered for QA devices. *(Intentional off on dev until beta.)*

### H-06 Admin CRUD on public Cloud Run with a single static key — Reported
- **Where:** `services/api/scripts/deploy.sh` (`--allow-unauthenticated`), `admin_auth.py`, `routers/admin_system_announcements.py`
- **Issue:** `/v1/admin/system-announcements` protected only by `X-Admin-Key`; no rate limit, no IP/IAM restriction; comparison is `!=` (not constant-time).
- **Fix:** `secrets.compare_digest`; rate-limit admin paths; consider IAP/IAM or a private admin surface; rotate key via Secret Manager.

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
| M-19 | Prod env lacks push-subscription / Cloud Build wiring present in dev; dev hardcodes worker URL; Run invoker IAM is script-managed, not Terraform | `environments/prod/main.tf`, `dev/main.tf`, `run_iam.tf` | Parameterize endpoint; manage invoker in TF |
| M-20 | Secret accessor granted to API and worker for all secrets (incl. `admin-api-key`) | `modules/platform/iam.tf` | Per-secret bindings |
| M-21 | Dev automation SA has `editor`, `serviceAccountAdmin`, `projectIamAdmin` | `iam.tf` | Keep dev-only; narrow roles |
| M-22 | Cloud SQL public IPv4 enabled, no private IP / VPC connector | `modules/platform/sql.tf` | Private IP or documented restriction |
| M-47 | Prod Terraform sets the SQL app password (`manage_sql_app_password = true`) but never writes it to Secret Manager; Cloud Run reads `db-lanonna-app-password:latest`, so a fresh prod apply can leave API/worker unable to connect | `environments/prod/main.tf:39`, `modules/platform/sql.tf:41-57`, `secrets.tf` | Add a `google_secret_manager_secret_version` from the generated password, or document a single bootstrap step |
| ✅ M-48 | No repo-root `.gcloudignore`/`.dockerignore`; deploys uploaded the whole monorepo; service-level `.dockerignore` was ignored with repo-root context | repo-root `.gcloudignore`, `.dockerignore`; `services/*/scripts/deploy.sh` | Whitelist `packages/` + `services/`; removed `services/api/.dockerignore` and `services/worker/.dockerignore` |
| M-49 | Dev Cloud SQL has no deletion protection (`deletion_protection = var.environment == "prod"`) and no `prevent_destroy` | `modules/platform/sql.tf:30` | Enable for dev or add `lifecycle { prevent_destroy }` |
| M-50 | Worker FCM permission (`roles/firebasecloudmessaging.admin`) is documented but not in Terraform; a fresh environment silently fails to push | `docs/engineering/operations.md`, `modules/platform/iam.tf` | Codify the role binding |
| M-51 | `run-beta-gate.sh` needs `services/api/.venv` and deploys API only (no worker/IAM) | `scripts/run-beta-gate.sh:11-21` | Reuse the `verify-dev-prerequisites.sh` venv pattern; match the documented deploy order |
| M-52 | Deploy scripts hardcode `ENVIRONMENT=dev` even if `GCP_PROJECT_ID` points elsewhere | `services/api/scripts/deploy.sh:44`, `services/worker/scripts/deploy.sh:38` | Derive from project id or require an explicit override |
| M-53 | Dev maintenance scripts are unsafe: `clear_dev_test_data.py --email` hard-deletes **every** baby the user has any membership row for (including followed and tombstoned) and fails on `votes` FK; no environment guard on `--email`/`hard_delete_user`; `hard_delete_user.py` inits Firebase with the default ADC project | `infra/db/clear_dev_test_data.py:36-44,89-97,122-160`, `infra/db/hard_delete_user.py:523,531-544` | Limit to active, sole-owned babies; delete `votes`; require an explicit dev env/project guard |

### Mobile

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-27 | App Check token silently omitted when `getToken` fails | `core/app_check/app_check_bootstrap.dart`, `core/api/api_client.dart` | Retry/backoff or visible warning |
| M-31 | Biometric unlock (PRD §5.3) not implemented — no `local_auth` usage | n/a | Implement or mark deferred in PRD |
| ✅ M-54 | Invite-mismatch PII in GoRouter query strings; invitee email in persisted preview JSON; Android Auto Backup of prefs | `InviteFlowState`, `invite_flow_navigation.dart`, `onboarding_wrong_email_screen.dart`, `AndroidManifest.xml` | In-memory mismatch/prefill/resume; preview JSON omits `invitee_email`; `allowBackup=false` + `backup_rules.xml` |
| M-55 | Signed-in invite accept screens show `e.toString()` of an `Exception` instead of mapped copy | `onboarding_follower_invite_screen.dart:82-88`, `onboarding_coowner_invite_screen.dart:82-88` | Use `inviteAcceptUserMessage` / `apiErrorMessage` / `runMutation` |
| M-56 | `AppSession.refreshFromApi` swallows all errors (`catch (_)`), so a failed status fetch can misroute (onboarding vs home) with no feedback | `onboarding/presentation/app_session.dart:46-57` | Surface an error/retry state or redirect conservatively |
| M-57 | Non-debug builds built with `MAESTRO_SEMANTICS=true` use the App Check debug provider and log the debug token | `core/app_check/app_check_bootstrap.dart:4-27`, `main.dart:18-24` | Restrict the debug provider to `kDebugMode`; guard token logging |
| M-58 | Announcement screens: `_load`/`_prefill` have no error handling (permanent spinner on failure); squish/comment failures are unhandled; four `TextEditingController`s never disposed | `announcement/presentation/announcement_card_screen.dart:42-72`, `announcement_create_screen.dart:34-77` | try/catch/finally with `apiErrorMessage` + `AppSnackBar`; dispose controllers |
| M-59 | Async hygiene: no `mounted` check before `setState` after awaits (gallery, home, names tab); global search swallows API errors; registry delete bypasses `runMutation`; gallery upload polling ends silently after ~24 s | `gallery_screen.dart:114-132,178-196`, `home_screen.dart:85-103`, `names_tab.dart:54-58`, `global_search_screen.dart:54-69`, `registry_screen.dart:298-303` | Guard with `mounted`; show errors; use `runMutation`; surface poll timeout |
| M-60 | Date handling violates the documented UTC-in/local-out rule: photo `created_at` formatted in UTC (wrong day for evening uploads); date-only API fields parsed with `DateTime.tryParse` instead of `tryParseApiCalendarDate` | `gallery/data/models/photo_models.dart:27`, `photo_detail_screen.dart:399,659-664`, `home_screen.dart:123-130`, `announcement_create_screen.dart:63-65` | Use `parseApiInstant` / `tryParseApiCalendarDate` helpers |
| M-61 | Event form has no owner guard (followers reaching the route see a full form that fails on save); cover thumbnail lacks `onSignedUrlError` so it breaks after the 900 s URL TTL | `calendar/presentation/event_form_screen.dart:106-116,413-418`, `widgets/event_form_widgets.dart:43-48` | Gate by role; pass a refresh callback |

### Tests

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| ✅ M-62 | Test suite red after review: invitation accept race, stale onboarding mock, Flutter harness missing providers | `test_invitation_accept_race.py`, `test_onboarding_domain.py`, mobile widget tests | Fix **M-36**; update mocks; add `ConnectivityService` / notification fakes |

---

## Low

| ID | Issue | Where |
|----|-------|-------|
| ✅ L-07 | Default API base URL baked in source; release builds must use `--dart-define-from-file` | `app_config.dart` — const `String.fromEnvironment('API_BASE_URL')`; release/profile compilation fails when it is empty. Debug omits the define and uses the dev URL. |
| L-08 | Accessibility: semantics labels concentrated in shell/onboarding; many controls unlabeled (WCAG AA is the PRD baseline) | mobile |
| L-09 | Hardcoded UI strings vs `app_en.arb` (FR-SET-002) | e.g. `account_edit_screen.dart`, `home_screen.dart` |
| ✅ L-10 | No CORS middleware (fine for mobile-only; needs policy if a web client is added) | `main.py`, `config.py` — `CORS_ALLOW_ORIGINS` comma-list; off when empty |
| L-14 | Poison/unknown Pub/Sub messages are logged and acked (204) with no metric; permanent rejects log `pubsub_payload_permanent_reject` (**M-46**); no alert on DLQ depth (the `…-dlq-pull` subscription retains messages, but nobody is notified) | `worker/main.py`, `worker/pubsub_payload.py`, `modules/platform/pubsub.tf` |
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
| L-28 | **Consolidation backlog (deferred, medium risk — live request paths):** gallery vs calendar comment domain logic and photo/event comment SQL; router `try/except map_domain_errors` boilerplate; dynamic `UPDATE … SET` builders; mobile comment composer, tab empty states, AI-suggestions screen state machine, labeled-field shell, wider `runMutation` use; shared `get_connection` for API + worker, `infra/db` shared `connect()` and invite-hash helper; Terraform push-subscription `for_each` and dev/prod API-list dedupe; scheduler script merge; PUT/PATCH announcement alias. Request-scoped `upsert_app_user` calls were replaced by `current_app_user` (#36). | `services/api`, `apps/mobile`, `infra/` |

---

## Test coverage gaps (still thin)

- **API:** No router/HTTP tests for `fun`, `registry`, `invitations`, `notifications`, `search`, `admin_system_announcements`, baby photo routes, and `/v1/uploads/display/signed-url`; only domain-level mocks for `onboarding`. Event create/update time-range validation has an HTTP test. Repositories have almost no direct SQL tests (`search_name_suggestions` has a column-conformance test, and `tests/integration/` runs search, provisioning, and the onboarding gate on Postgres); also untested: `account`, `pubsub`, `storage`, `media_urls`, `membership`.
- **Mobile:** Untested core modules: `api_client`, `auth_repository`, `user_deleted_session_handler`, `push_notification_service`, `app_router`, `app_link_bootstrap`, `onboarding_storage`, `onboarding_coordinator`, `shell/`. No tests for `search/`, `settings/`, `legal/`, `home_activity_screen`, `calendar_upcoming_screen`, wrong-email and invite-bootstrap screens. `integration_test/` has only `home_summary_load_test.dart` and `smoke_sign_in_test.dart`. `session_cleanup_test.dart` covers local wipe on sign-out; `delete_account_screen_test.dart` only checks copy.
- **Worker:** Push routes now have poison-payload and export-dispatch tests (`test_main_pubsub_payload.py`, `test_main_export_dispatch.py`); invite HTML escaping, FCM chunking, and `pubsub_payload` have unit tests. Baby export SQL is covered by `services/api/tests/integration/test_baby_data_export_postgres.py` (real Postgres, including the baby-graph table manifest). Still thin: weekly digest, Mailjet claim-release edge cases. Lifecycle export tests stub the document builder.

---

## Suggested fix order

1. **Pre-beta security:** H-01, H-04, H-05, H-06, M-27, M-57
2. **Mobile correctness:** M-54–M-61
3. **Infra + prod parity:** M-19–M-22, M-47–M-53
4. **Ops / polish:** M-09, M-31, L-08–L-09, L-14–L-16, L-22, L-26; then the L-28 consolidation backlog
