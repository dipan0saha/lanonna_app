# Open gaps (pre-beta)

Open engineering gaps for La Nonna. Seeded from the Oct 2026 full-stack review and extended by a second full code review on **2026-10-11** (API, data layer, worker, mobile, infra/docs) plus live test runs. Completed items are removed; see git history for the original audit.

**Legend:** **Verified** — confirmed by reading the cited code and/or running the tests; **Reported** — suspected, not fully traced.

Related: [pre-beta-qa.md](pre-beta-qa.md), [development.md](development.md), [operations.md](operations.md).

---

## Health snapshot (2026-10-11)

| Check | Result |
|-------|--------|
| API `pytest` (`services/api`) | **187 passed, 3 failed** — `test_invitation_accept_race.py` (2), `test_onboarding_domain.py::test_complete_owner_onboarding_requires_email_verified` (stale mock) |
| Worker `pytest` | 26 passed |
| `flutter test` | **211 passed, 5 failed** — `home_screen_first_run_test.dart` (2), `gallery_list_refresh_test.dart` (2), `calendar_event_refresh_test.dart` (1); all missing `Provider<ConnectivityService>` in the test harness |
| `flutter analyze` | 0 errors, 0 warnings, 48 infos |

**Reopened / regressions found in this review**

- **M-02 (co-owner accept race) is not actually fixed.** Commit `5b1b678` added the import and `lock_baby_profile_for_update()` but the accept path never calls it; the new tests fail. Tracked as **M-36**.
- **M-11 (export retry) fix introduced H-09:** the Pub/Sub `messageId` dedupe added in `main.py` drops the redelivery that the reclaim/failed logic depends on.
- **M-18 (DLQ) fix introduced H-13:** the dead-letter topic has no subscription, so dead-lettered messages are not retained.

---

## Summary

| Severity | Open | Themes |
|----------|------|--------|
| High | 11 | Release signing, worker OIDC, App Check enforce, admin surface; export retry regression, broken search, sign-out data leakage, lost photo notifications, DLQ black hole, iOS privacy strings, gallery truncation |
| Medium | 36 | Co-owner race, ended-member 500s, races/N+1, Pub/Sub robustness, export limits, invite token/HTML hygiene, infra/IAM/prod parity, mobile error/async/date handling, red test suite |
| Low | 17 | Input caps, dead config, logging, infra hygiene, docs drift, lint/conventions |

---

## High

### H-01 Android release is signed with debug keys — Verified
- **Where:** `apps/mobile/android/app/build.gradle.kts` (release `signingConfig = signingConfigs.getByName("debug")`)
- **Issue:** Release APK/AAB uses the debug keystore (TODO left in file). Not acceptable for Play upload or any distribution you intend to update in place.
- **Fix:** Add an upload keystore + `signingConfigs.release` read from `key.properties` / release signing secrets; keep debug signing only for local `flutter run --release`.

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

### H-09 Export Pub/Sub dedupe drops the retries that recovery depends on — Verified
- **Where:** `services/worker/src/lanonna_worker/main.py:123-137`, `services/worker/src/lanonna_worker/db.py:37-39`, `services/worker/src/lanonna_worker/baby_data_export.py`
- **Issue:** `try_claim_delivery(conn, f"pubsub:{messageId}")` runs in its own `get_connection()` block, which **commits on exit**, before `run_baby_data_export()` runs. If the export fails (or the instance dies after the job is set to `running`), the handler returns 500; Pub/Sub redelivers the **same** `messageId`, the claim already exists, and the redelivery is acked with **204** without running. The stale-`running` reclaim and failure handling added for M-11 are unreachable via Pub/Sub retry; the job stays `running`/`failed` until the user creates a new export.
- **Fix:** Drop the message-id claim for exports (the job row status/`started_at` is already the idempotency guard), or release the claim on failure / key it on a successful terminal state.

### H-10 Baby search fails: queries a non-existent column — Verified
- **Where:** `services/api/src/lanonna_api/repositories/search.py:85-90` (`SELECT id, name … name ILIKE`) vs `infra/db/migrations/004_onboarding_first_moment.sql:33` (`suggested_name`); caller `domain/search.py:57-59`
- **Issue:** `name_suggestions` has `suggested_name`, not `name`, so the name-suggestion leg of `GET /v1/babies/{id}/search` raises Postgres `undefined_column` and fails the whole search response for any non-empty query that reaches it. Domain tests mock the repository, so this is untested.
- **Fix:** `SELECT id, suggested_name AS name … WHERE suggested_name ILIKE …`; add a repository-level SQL test.

### H-11 Sign-out and account delete leave cross-user local state — Verified
- **Where:** `apps/mobile/lib/features/account/presentation/account_screen.dart:66-71`, `delete_account_screen.dart:64`, `core/auth/user_deleted_session_handler.dart:21-23`, `features/home/data/home_repository.dart:15-34`, `features/onboarding/presentation/app_session.dart:110-122`
- **Issue:** Normal sign-out and delete-account only call `resetOwnerCompletionForSignOut()`. They do **not** clear `pending_invite_token` / invite preview JSON (contains invitee email), `selected_baby_id`, onboarding drafts, `HomeRepository._cachedBabies` (`clearCachedBabies()` has no callers; `listBabies()` serves the cache on **any** error), or the image disk cache. Only the `user_deleted` 401 path clears the invite. On a shared device the next user can be redirected into the previous user's invite flow and see their cached babies/avatars when offline.
- **Fix:** One `SessionCleanup` used by every sign-out path: clear pending invite, selected baby, home cache, onboarding state, push token, and evict the image cache; key cached data by uid.

### H-12 Photo-ready notification lost if fan-out fails after the claim — Verified
- **Where:** `services/worker/src/lanonna_worker/thumbnails.py:96-127`, `idempotency.py:22-39`
- **Issue:** `try_claim_photo_ready_notify` commits in its own transaction, **then** `process_notify_fan_out` runs. If fan-out raises, the GCS message returns 500 and is retried, but the retry sees the claim and skips notify permanently; members never get the "new photo" notification.
- **Fix:** Claim after a successful fan-out, delete the claim on failure, or enqueue fan-out as its own Pub/Sub command with retry/DLQ.

### H-13 Dead-letter topic has no subscription — Verified
- **Where:** `infra/terraform/modules/platform/pubsub.tf:23-32` (topic), `:73-76` and `:100-103` (both push subs dead-letter to it); no `google_pubsub_subscription` targets the DLQ topic
- **Issue:** After 5 failed deliveries messages are published to a topic with no subscriber, so they are not retained and cannot be inspected or replayed. Poison or persistently failing invite/notification/export messages are silently lost.
- **Fix:** Add a pull subscription on the DLQ topic (with message retention) and a Cloud Monitoring alert on DLQ publish/oldest-unacked age; document replay.

### H-14 iOS camera/photo-library usage descriptions are missing — Verified
- **Where:** `apps/mobile/ios/Runner/Info.plist` (no `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`); `image_picker` is used in account edit, create-baby, and onboarding
- **Issue:** On iOS, opening the camera or photo library without these keys crashes the app and fails App Store review.
- **Fix:** Add accurate usage strings (and `NSPhotoLibraryAddUsageDescription` if saving images).

### H-15 Gallery silently truncates after 50 photos — Verified
- **Where:** `apps/mobile/lib/features/gallery/data/gallery_repository.dart:16-27` (never sends `limit`/`offset`); API `routers/photos.py:78-79` (`limit` default 50, max 100)
- **Issue:** Babies with more than 50 photos get an incomplete grid with no pagination or end-of-list signal; newer photos silently hide older ones.
- **Fix:** Paginate in the repository/UI (infinite scroll or loop with `offset`) and show an end-of-list state.

---

## Medium

### API

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-09 | Rate limiting only on photo init and batch invite; per-instance buckets | `middleware/rate_limit.py` | Edge limiter for preview/admin; document scaling caveat |
| M-36 | **Co-owner accept race still open (M-02 reopened):** `lock_baby_profile_for_update` is imported but never called; `count_active_owners` runs unlocked, so two concurrent accepts can exceed the 2-owner cap. Both tests in `test_invitation_accept_race.py` fail | `repositories/invitations.py:11-12,232`, `repositories/memberships.py:47-62` | Call the lock (and `FOR UPDATE`) before counting owners inside the accept transaction; get the tests green |
| M-37 | Ended (removed) members get **500** instead of `403 membership_ended` on `GET /search`, all invitation owner routes (list/revoke/batch/membership-check), `GET /members`, and first-moment seed — routers catch only `PermissionError`, not `MemberLifecycleError` | `routers/search.py:24-27`, `routers/invitations.py:50-108`, `routers/members.py:41-44`, `routers/babies.py:172-181` | Use `except Exception as exc: raise map_domain_errors(exc)` like `home-summary`; add router tests |
| M-38 | Concurrent registry purchase claims: check-then-insert on `purchase_id`; the loser hits the `registry_item_id` unique violation and returns 500 (winner may still notify) | `domain/registry.py:167-175`, `repositories/registry.py:258-270`, migration `008` | Single `INSERT … ON CONFLICT DO NOTHING RETURNING`, map conflict to 409 |
| M-39 | Fun: one-like-per-gender is not atomic (separate transactions); follower name cap (count then insert) is racy with no unique index; `list_names` does an N+1 `user_has_like` per suggestion | `domain/fun.py:46-139`, `repositories/fun.py:63-216` | Single transaction + row lock / partial unique index; fetch liked ids in one query |
| M-40 | Photo `tagged_babies` join ignores `removed_at` and `deleted_at`, so removed members' or soft-deleted babies' names can still appear | `repositories/photo_tags.py:15-27` | Add `m.removed_at IS NULL AND b.deleted_at IS NULL` |

### Worker / data

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-15 | Thumbnail download loads whole object in memory, no size/dimension cap | `worker/thumbnails.py` | Cap bytes/dimensions |
| M-16 | Worker config defaults to dev project/buckets if env unset | `worker/config.py` | Fail fast outside dev |
| M-41 | Raw `invite_token` is published in the Pub/Sub command payload; unknown-message branch logs the whole payload. Anyone with subscribe/log access can accept invites | `api/pubsub.py:33-38`, `worker/main.py:69-76,154-158` | Publish only `invitation_id`; worker reads a single-use send secret from DB; redact logs |
| M-42 | Invite HTML email interpolates `inviter_display_name`, `baby_name`, `relationship_label` unescaped (HTML injection into the invitee's mail client) | `worker/invite_email_copy.py:23-33`, `worker/invite_email.py:126-133` | `html.escape()` all user-derived fields; test it |
| M-43 | Export robustness: stale-`running` reclaim at 30 min can overlap a slow run (no lease/heartbeat, `ready` update unguarded); whole bundle built in memory at 512 Mi; GCS upload success + DB failure leaves a `failed` job and an orphan object | `worker/baby_data_export.py:27-37,96-163`, `worker/scripts/deploy.sh` | Heartbeat or guard `UPDATE … WHERE status='running'`; stream/paginate; delete object on failed finalize |
| M-44 | Weekly digest deletes FCM tokens on **any** failure (not only permanent ones) and FCM multicast is not chunked at 500 tokens | `worker/notifications.py:182-199,355-370` | Reuse `_should_delete_fcm_token`; chunk sends |
| M-45 | Subscription ack deadline is 120 s but the worker Cloud Run request timeout is the 300 s default, so slow handlers get redelivered while still running | `pubsub.tf:63,90`, `worker/scripts/deploy.sh` | Set worker `--timeout` ≤ 120 s or raise ack deadline; align with export/thumbnail time |
| M-46 | Permanent bad payloads (malformed base64, non-UUID `job_id`/`invitation_id`) return 500 and retry to the DLQ instead of being acked | `worker/main.py:64-68,76,133-136` | Validate and return 204 with a log/metric for permanent errors (ties to L-14) |

### Infra

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-19 | Prod env lacks push-subscription / Cloud Build wiring present in dev; dev hardcodes worker URL; Run invoker IAM is script-managed, not Terraform | `environments/prod/main.tf`, `dev/main.tf`, `run_iam.tf` | Parameterize endpoint; manage invoker in TF |
| M-20 | Secret accessor granted to API and worker for all secrets (incl. `admin-api-key`) | `modules/platform/iam.tf` | Per-secret bindings |
| M-21 | Dev automation SA has `editor`, `serviceAccountAdmin`, `projectIamAdmin` | `iam.tf` | Keep dev-only; narrow roles |
| M-22 | Cloud SQL public IPv4 enabled, no private IP / VPC connector | `modules/platform/sql.tf` | Private IP or documented restriction |
| M-47 | Prod Terraform sets the SQL app password (`manage_sql_app_password = true`) but never writes it to Secret Manager; Cloud Run reads `db-lanonna-app-password:latest`, so a fresh prod apply can leave API/worker unable to connect | `environments/prod/main.tf:39`, `modules/platform/sql.tf:41-57`, `secrets.tf` | Add a `google_secret_manager_secret_version` from the generated password, or document a single bootstrap step |
| M-48 | No repo-root `.gcloudignore`/`.dockerignore`; deploys upload the whole monorepo (~13k files / ~680 MB per build); service-level `.dockerignore` files are ignored with a repo-root context | `services/*/scripts/deploy.sh`, `services/*/cloudbuild.yaml` | Add root `.gcloudignore` and `.dockerignore` limited to `services/`, `packages/`, Dockerfiles |
| M-49 | Dev Cloud SQL has no deletion protection (`deletion_protection = var.environment == "prod"`) and no `prevent_destroy` | `modules/platform/sql.tf:30` | Enable for dev or add `lifecycle { prevent_destroy }` |
| M-50 | Worker FCM permission (`roles/firebasecloudmessaging.admin`) is documented but not in Terraform; a fresh environment silently fails to push | `docs/engineering/operations.md`, `modules/platform/iam.tf` | Codify the role binding |
| M-51 | `run-beta-gate.sh` needs `services/api/.venv`, deploys API only (no worker/IAM), and prints a stale "migration 020" hint | `scripts/run-beta-gate.sh:11-21` | Reuse the `verify-dev-prerequisites.sh` venv pattern; match the documented deploy order |
| M-52 | Deploy scripts hardcode `ENVIRONMENT=dev` even if `GCP_PROJECT_ID` points elsewhere | `services/api/scripts/deploy.sh:44`, `services/worker/scripts/deploy.sh:38` | Derive from project id or require an explicit override |
| M-53 | Dev maintenance scripts are unsafe: `clear_dev_test_data.py --email` hard-deletes **every** baby the user has any membership row for (including followed and tombstoned) and fails on `votes` FK; no environment guard on `--email`/`hard_delete_user`; `hard_delete_user.py` inits Firebase with the default ADC project | `infra/db/clear_dev_test_data.py:36-44,89-97,122-160`, `infra/db/hard_delete_user.py:523,531-544` | Limit to active, sole-owned babies; delete `votes`; require an explicit dev env/project guard |

### Mobile

| ID | Issue | Where | Fix |
|----|-------|-------|-----|
| M-27 | App Check token silently omitted when `getToken` fails | `core/app_check/app_check_bootstrap.dart`, `core/api/api_client.dart` | Retry/backoff or visible warning |
| M-31 | Biometric unlock (PRD §5.3) not implemented — no `local_auth` usage | n/a | Implement or mark deferred in PRD |
| M-54 | Invite-mismatch emails (invitee + signed-in) are embedded in GoRouter query strings; invite token/preview JSON sit in plaintext `SharedPreferences` and Android backup is not disabled | `features/onboarding/.../invite_flow_navigation.dart:73-78`, `onboarding_wrong_email_screen.dart:18-22`, `onboarding_storage.dart:22-26,177-183`, `AndroidManifest.xml` | Pass mismatch state via an in-memory store; `allowBackup="false"` / exclude prefs |
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
| M-62 | Test suite is red: 3 API tests (M-36 lock + a stale onboarding test that mocks `user_has_owner_baby` while code calls `user_has_self_created_baby`) and 5 Flutter tests (harness lacks `Provider<ConnectivityService>`) | `services/api/tests/test_invitation_accept_race.py`, `test_onboarding_domain.py:28-37`, `apps/mobile/test/{home_screen_first_run,gallery_list_refresh,calendar_event_refresh}_test.dart` | Fix the code (M-36) and update the stale tests/harnesses; run all suites before every ship |

---

## Low

| ID | Issue | Where |
|----|-------|-------|
| L-07 | Default API base URL baked in source; release builds must use `--dart-define-from-file` | `config/app_config.dart` |
| L-08 | Accessibility: semantics labels concentrated in shell/onboarding; many controls unlabeled (WCAG AA is the PRD baseline) | mobile |
| L-09 | Hardcoded UI strings vs `app_en.arb` (FR-SET-002) | e.g. `account_edit_screen.dart`, `home_screen.dart` |
| L-10 | No CORS middleware (fine for mobile-only; needs policy if a web client is added) | `services/api/main.py` |
| L-14 | Poison/unknown Pub/Sub messages are logged and acked (204) with no metric | `worker/main.py` |
| L-15 | Dockerfiles run as root; Cloud Build only builds/pushes (no tests); base images use floating `python:3.12-slim` tags | `services/*/Dockerfile`, `cloudbuild.yaml` |
| L-16 | Duplicate email template trees (intentional); run `scripts/sync-email-templates.sh check` locally before commit | `packages/email-templates`, `services/worker/email_templates` |
| L-17 | Unbounded inputs: photo caption PATCH (init caps 2000), photo tags list, fun name `suggested_name`, event/registry title/description/location, membership-check `email` query | `routers/photos.py:17-37`, `routers/fun.py:21-22`, `routers/events.py:18-36`, `routers/registry.py:21-33`, `routers/invitations.py:76-79` |
| L-18 | Search `q` is not escaped for `ILIKE` wildcards (`%`, `_`); `PermissionError` returns a plain string `detail` while lifecycle errors return `{error,message}` | `domain/search.py:22-33`, `http_errors.py:42-47` |
| L-19 | Calendar `list_events` has no `LIMIT` when no month/upcoming filter; storage usage counts soft-deleted babies | `repositories/events.py:13-46`, `repositories/user_engagement.py:71-81` |
| L-20 | Dead config: API `invite_deep_link_base` (worker-only), Terraform `var.pubsub_subscription_worker` + deprecated null output, stale `project.env` keys for the removed pull sub | `config.py:31-32`, `modules/platform/variables.tf:43-46`, `outputs.tf:25-27`, `infra/gcp/project.env` |
| L-21 | Worker hygiene: unknown messages log the full payload (PII/token risk); export uses `SELECT *` (internal columns) and silently truncates activity to 500 rows | `worker/main.py:154-158`, `worker/baby_data_export.py:96-137` |
| L-22 | Infra hygiene: GCS buckets lack `public_access_prevention`/versioning/lifecycle; `import-dev.sh` omits the `admin-api-key` secret; `infra/gcp/project.env` commits the billing account id (not a credential) | `modules/platform/storage.tf`, `scripts/import-dev.sh:40-41`, `infra/gcp/project.env` |
| L-23 | Docs drift: `development.md` mobile module table omits `fun/`, `search/`, `settings/`, `legal/`, `/home/activity`, `/notifications/inbox`; `/health` undocumented; `services/worker/README.md` omits export in the intro and says a DLQ is future work; `infra/gcp/SETUP.md` still lists the pull sub and manual TokenCreator; `operations.md` migration block mixes `cd infra/db` with a repo-root script path; `verify-dev-migrations.sh` header says 001–023; helper scripts (`provision_qa_validation_accounts.sh`, `seed_qa_gallery_photo.sh`, `configure-android-google-sign-in.sh`, `copy_release_apk_to_drive.sh`) are undocumented | see list |
| L-24 | Mobile hygiene: FCM unregister failures swallowed; `RouterRefreshListenable` auth stream subscription never cancelled; Android release has no R8/minify rules | `core/notifications/push_notification_service.dart:118-127`, `core/router/router_refresh.dart:13-16`, `android/app/build.gradle.kts:37-42` |
| L-25 | Convention violations: ~13 hardcoded hex colors in `features/` (e.g. `onboarding_buttons.dart:108`, `batch_invite_screen.dart:296`, `event_form_widgets.dart:38-39`); hardcoded strings in `batch_invite_screen.dart`, `onboarding_wrong_email_screen.dart`, `app.dart`; batch invite submit bypasses `runMutation`; hand-rolled count strings in `predictions_tab.dart:399`, `names_tab.dart:328`, `gallery_photo_grid.dart:109` | mobile |
| L-26 | `flutter analyze`: 48 infos — `use_null_aware_elements` (registry/home/onboarding repositories), `unnecessary_underscores`, 4 `use_build_context_synchronously` in login/signup screens, deprecated `value` on a form field | mobile `lib/`, `test/` |

---

## Test coverage gaps (still thin)

- **API:** No router/HTTP tests for `events`, `fun`, `registry`, `invitations`, `notifications`, `search`, `admin_system_announcements`, baby photo routes, and `/v1/uploads/display/signed-url`; only domain-level mocks for `onboarding`. Repositories have no direct SQL tests (this is how H-10 shipped); also untested: `account`, `pubsub`, `storage`, `media_urls`, `membership`.
- **Mobile:** Untested core modules: `api_client`, `auth_repository`, `user_deleted_session_handler`, `push_notification_service`, `app_router`, `app_link_bootstrap`, `onboarding_storage`, `onboarding_coordinator`, `shell/`. No tests for `search/`, `settings/`, `legal/`, `home_activity_screen`, `calendar_upcoming_screen`, wrong-email and invite-bootstrap screens. `integration_test/` has only `home_summary_load_test.dart` and `smoke_sign_in_test.dart`. Existing tests like `delete_account_screen_test.dart` only check copy.
- **Worker:** No tests for `main.py` (push routing, dedupe, status codes), `config.py`, weekly digest, photo-ready notify failure ordering (H-12), export reclaim/dedupe interaction (H-09), invite-email Mailjet failure/claim release and HTML escaping. Tests are mock-heavy (SQL string matching), so idempotency regressions would not fail.

---

## Suggested fix order

1. **Regressions and broken behavior:** H-09, H-10, M-36, M-62 (get all suites green), H-12, H-13
2. **Pre-beta security:** H-01, H-04, H-05, H-06, M-27, M-41, M-42, M-57
3. **Mobile correctness:** H-11, H-14, H-15, M-54–M-61
4. **API/worker robustness:** M-37–M-40, M-43–M-46
5. **Infra + prod parity:** M-19–M-22, M-47–M-53
6. **Ops / polish:** M-09, M-15, M-16, M-31, L-07–L-26
