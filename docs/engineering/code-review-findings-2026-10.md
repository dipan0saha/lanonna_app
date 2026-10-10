# Code review findings — October 2026

Full-stack review of mobile (`apps/mobile`), API (`services/api`), worker (`services/worker`), infra (`infra/`), scripts, and docs. Static review only (no live GCP, no `terraform plan`). `flutter analyze` was run: **0 errors, 4 warnings, ~110 infos** (mostly `use_build_context_synchronously`).

**Legend**

- **Verified** — confirmed by reading the cited code in a second pass.
- **Reported** — found in the review pass, not independently re-read.
- Status: `Open` or **✅ Fixed** (2026-10 quick-fix batch + related commits).

Related: [remediation-plan.md](remediation-plan.md) (earlier phased plan), [pre-beta-qa.md](pre-beta-qa.md).

---

## Summary

| Severity | Count | Theme |
|----------|-------|--------|
| High | 8 | Release signing, worker auth, ended-member 500s, delete ordering, App Check/admin exposure, silent save failures, invite accept result ignored |
| Medium | 24 | Error UX, validation gaps, idempotency, IAM/infra parity, doc drift, test gaps |
| Low | 16 | Lint, PII in logs, minor consistency |

---

## High

### H-01 Android release is signed with debug keys — Verified
- **Where:** `apps/mobile/android/app/build.gradle.kts` (release `signingConfig = signingConfigs.getByName("debug")`)
- **Issue:** Release APK/AAB uses the debug keystore (TODO left in file). Not acceptable for Play upload or any distribution you intend to update in place.
- **Fix:** Add an upload keystore + `signingConfigs.release` read from `key.properties` / CI secrets; keep debug signing only for local `flutter run --release`.
- **Status:** Open

### H-02 Ended members get HTTP 500 on home routes — Verified
- **Where:** `services/api/src/lanonna_api/routers/babies.py` (`home_summary`, `activity_events` catch only `PermissionError`); `domain/home.py` (`require_active_membership`); `domain/member_errors.py` (`MemberLifecycleError(Exception)`, not a `PermissionError`)
- **Issue:** `require_active_membership` raises `MemberLifecycleError` for removed members. The routers don’t map it, so it reaches the global handler in `main.py` and returns **500**. `development.md` documents **403** with `detail.error == membership_ended` and the mobile client has handling for it.
- **Fix:** Use `except Exception as exc: raise map_domain_errors(exc)` (as in `routers/search.py` / `routers/photos.py`) or add `MemberLifecycleError` to the except clause. Add a router-level test.
- **Status:** ✅ Fixed

### H-03 Account delete removes Firebase user before SQL anonymization — Verified
- **Where:** `services/api/src/lanonna_api/domain/account_delete.py` (`delete_account`)
- **Issue:** `firebase_auth.delete_user` runs first; `soft_delete_account_rows` second. If SQL fails, the user can no longer sign in but their profile/baby rows remain un-anonymized, and the client can’t retry (no auth).
- **Fix:** Do SQL soft-delete/anonymize first (single transaction), then delete the Firebase user; on Firebase failure, leave a retryable state (e.g. flag + retry) or compensate.
- **Status:** Open

### H-04 Worker `/pubsub/push` has no in-app OIDC verification — Verified (grep) / Reported (impact)
- **Where:** `services/worker/src/lanonna_worker/main.py` (push + cron routes); no `Authorization` / OIDC verification anywhere in `services/worker/src`
- **Issue:** Security rests entirely on Cloud Run `run.invoker`. Any principal granted invoker can POST arbitrary payloads (notify, export, invite email). Docs describe OIDC push but the app does not validate the token. Cron HTTP routes are likewise unauthenticated at the app layer.
- **Fix:** Verify Google OIDC JWT (audience = worker URL; expected push/scheduler service account email). Remove HTTP cron routes if Scheduler uses Pub/Sub only.
- **Status:** Open

### H-05 App Check not enforced by default — Verified (config/deploy)
- **Where:** `services/api/src/lanonna_api/config.py` (`app_check_enforce = False`); `services/api/scripts/deploy.sh` (`APP_CHECK_ENFORCE` defaults `false`, TEMP note)
- **Issue:** NFR-SEC-002 requires enforcement before public beta. With enforce off, missing/invalid App Check tokens are only logged. Combined with `--allow-unauthenticated`, JWT is the only gate.
- **Fix:** Enable for beta/prod (`APP_CHECK_ENFORCE=true`), keep dev override documented, ensure debug tokens are registered for QA devices.
- **Status:** Open (intentional temporary default; track before beta)

### H-06 Admin CRUD on public Cloud Run with a single static key — Reported
- **Where:** `services/api/scripts/deploy.sh` (`--allow-unauthenticated`), `admin_auth.py`, `routers/admin_system_announcements.py`
- **Issue:** `/v1/admin/system-announcements` protected only by `X-Admin-Key`; no rate limit, no IP/IAM restriction; comparison is `!=` (not constant-time).
- **Fix:** `secrets.compare_digest`; rate-limit admin paths; consider IAP/IAM or a private admin surface; rotate key via Secret Manager.
- **Status:** Open

### H-07 Signed-in invite accept ignores the API result — Verified
- **Where:** `apps/mobile/lib/features/onboarding/presentation/screens/follower/onboarding_follower_invite_screen.dart` (`_acceptInvitation`), same pattern in `coowner/onboarding_coowner_invite_screen.dart`
- **Issue:** `InvitationsRepository.accept` returns an `InvitationAcceptResult` with `error` (e.g. `email_mismatch`) instead of throwing. The screens discard it and always call `completeInviteOnboarding()` + `go('/home')`, so a wrong-email accept looks successful and drops the user on Home with no membership. The post-profile path (`invite_flow_navigation.dart`) handles this correctly.
- **Fix:** Branch on `result.error` (wrong-email route / `inviteAcceptUserMessage`), only complete onboarding on success.
- **Status:** Open

### H-08 Save/load flows with no error handling — Verified (account edit, followers) / Reported (others)
- **Where:**
  - `account_edit_screen.dart` `_save` — `try/finally` with no `catch`; upload/API failure gives no feedback and the exception propagates.
  - `followers_screen.dart` `_load` — two awaits, no `try/catch`, no error state.
  - Reported same pattern: `baby_edit_screen.dart`, `announcement_create_screen.dart`, `notifications_inbox_screen.dart`.
- **Fix:** `catch (e)` → `AppSnackBar.showAlert(context, apiErrorMessage(e))` for saves; error + retry UI for loads.
- **Status:** Open

---

## Medium

### API

| ID | Issue | Where | Fix | Status |
|----|-------|-------|-----|--------|
| M-01 | Owner-gated routes return generic 403 for ended owners, not structured `membership_ended` | `domain/membership.py`, `repositories/babies.py` | If `has_removed_membership`, raise `MemberLifecycleError("membership_ended", …)` | ✅ Fixed |
| M-02 | Co-owner accept race: `count_active_owners` then insert without row lock / constraint | `repositories/invitations.py` (accept path) | `SELECT … FOR UPDATE` on baby row or DB constraint; re-check inside lock | Open |
| M-03 | Photo init commits pending row before content-type validation; `byte_length` has no upper bound in schema | `domain/gallery.py`, `routers/photos.py` | Validate content type first; add `le=2_097_152` | ✅ Fixed |
| M-04 | Comment bodies unbounded (`min_length=1` only) on photos/events/announcements | `routers/photos.py`, `events.py`, `announcements.py` | Add `max_length` aligned with product/DB | ✅ Fixed |
| M-05 | Event `cover_photo_id` not validated as belonging to the baby on create/update | `domain/calendar.py` | `get_photo_for_baby` when set | ✅ Fixed |
| M-06 | Announcement `photo_id` not validated on write | `domain/announcement.py` | Same as M-05 | ✅ Fixed |
| M-07 | PII in logs: invite email in batch failure log | `domain/invitations.py` | Log `invitation_id` only | ✅ Fixed |
| M-08 | Export queue failure message returned to client and stored in job row | `domain/data_export.py`, `http_errors.py` | Generic client message; log details server-side | ✅ Fixed |
| M-09 | Rate limiting only on photo init and batch invite; per-instance buckets | `middleware/rate_limit.py` | Edge limiter for preview/admin; document scaling caveat | Open |
| M-10 | Invite token TTL is **14 days** in code, product copy says **7-day** private link (FR-INV-008) | `repositories/invitations.py` (`timedelta(days=14)`); `requirements.md` | Align code or copy | ✅ Fixed |

### Worker / data

| ID | Issue | Where | Fix | Status |
|----|-------|-------|-----|--------|
| M-11 | Export job can stick in `running` after a crash; retries exit as already-running; no reaper | `worker/baby_data_export.py` | Reclaim stale `running`; dedupe on message id; cap attempts | Open |
| M-12 | Invite email: send-then-mark ordering can duplicate on crash; two workers can race on `email_sent_at IS NULL` | `worker/invite_email.py` | Claim row before send or use `worker_delivery_log` | Open |
| M-13 | Missing Mailjet config logs and returns → handler 204 → message acked, invite never sent | `worker/invite_email.py`, `main.py` | Return 5xx or mark failed | ✅ Fixed |
| M-14 | Weekly digest HTTP cron path has no batch dedupe (Pub/Sub path does) | `worker/notifications.py`, `main.py` | Prefer Scheduler→Pub/Sub only; fixed dedupe key | ✅ Fixed |
| M-15 | Thumbnail download loads whole object in memory, no size/dimension cap | `worker/thumbnails.py` | Cap bytes/dimensions | Open |
| M-16 | Worker config defaults to dev project/buckets if env unset | `worker/config.py` | Fail fast outside dev | Open |
| M-17 | Migration `023` has **no `schema_migrations` insert** (021/022 do), so `apply_migrations.py` re-executes it every run. DDL uses `IF [NOT] EXISTS`, so re-run is harmless but untracked. It also **drops** `registry_shipping_address` with **no backfill** into the new `registry_shipping_*` columns | `infra/db/migrations/023_registry_shipping_structured.sql` | Add tracking insert; backfill legacy text (or confirm no data) before drop | Open |

> Correction vs. initial review pass: the review first described 023 as non-idempotent on re-apply. On re-reading, the `DROP COLUMN IF EXISTS` / `ADD COLUMN IF NOT EXISTS` statements make re-runs safe; the real defects are the missing tracking row and the lossy drop.

### Infra

| ID | Issue | Where | Fix | Status |
|----|-------|-------|-----|--------|
| M-18 | No dead-letter / retry policy on push subscriptions; upload topic also has a pull sub nothing consumes (backlog grows) | `infra/terraform/modules/platform/pubsub.tf` | DLQ + max delivery attempts; drop pull sub or document | Open |
| M-19 | Prod env lacks push-subscription / Cloud Build wiring present in dev; dev hardcodes worker URL; Run invoker IAM is script-managed, not Terraform | `environments/prod/main.tf`, `dev/main.tf`, `run_iam.tf` | Parameterize endpoint; manage invoker in TF | Open |
| M-20 | Secret accessor granted to API and worker for all secrets (incl. `admin-api-key`) | `modules/platform/iam.tf` | Per-secret bindings | Open |
| M-21 | Dev automation SA has `editor`, `serviceAccountAdmin`, `projectIamAdmin` | `iam.tf` | Keep dev-only; narrow roles | Open |
| M-22 | Cloud SQL public IPv4 enabled, no private IP / VPC connector | `modules/platform/sql.tf` | Private IP or documented restriction | Open |

### Mobile

| ID | Issue | Where | Fix | Status |
|----|-------|-------|-----|--------|
| M-23 | Registry load failure swallowed → empty UI; claim/undo purchase has no error handling | `features/registry/presentation/registry_screen.dart` | Error state + `runMutation` | Open |
| M-24 | Home: offline + cached summary still shows `MaterialBanner` from `_summaryError` (NFR-OFFLINE-001) | `features/home/home_screen.dart` | Suppress banner when offline with cached data | ✅ Fixed |
| M-25 | Raw exception text shown to users: gallery upload (`'Upload failed: $e'`), create-baby non-fatal errors | `gallery_screen.dart`, `baby/domain/create_baby_submit.dart` | `apiErrorMessage` | ✅ Fixed |
| M-26 | Invite deep-link bootstrap maps any network error to “not found”; invite preview helper silently redirects to owner carousel on any error | `invite_accept_bootstrap_screen.dart`, `invite_landing_helpers.dart` | Distinguish offline/5xx from 404; show retry | Open |
| M-27 | App Check token silently omitted when `getToken` fails | `core/app_check/app_check_bootstrap.dart`, `core/api/api_client.dart` | Retry/backoff or visible warning | Open |
| M-28 | `/profile/edit` is allowed by deep-link prefix `/profile` but only `/account/edit` is routed; PRD §5.2 says `/profile/edit`, FR-PROF-002 says `/account/edit` | `core/router/deep_link_navigation.dart`, `app_router.dart`, `requirements.md` | Redirect `/profile/edit`→`/account/edit`; fix PRD §5.2 | ✅ Fixed |
| M-29 | Calendar tab uses fixed error string (no `apiErrorMessage`, no offline handling) | `calendar_screen.dart` | Align with gallery/fun | ✅ Fixed |
| M-30 | Deleted-account handler signs out silently; membership-ended uses raw `ScaffoldMessenger` (violates `AppSnackBar` rule) | `core/auth/user_deleted_session_handler.dart`, `membership_access_handler.dart` | Show message via `AppSnackBar` | ✅ Fixed |
| M-31 | Biometric unlock (PRD §5.3) not implemented — no `local_auth` usage | n/a | Implement or mark deferred in PRD | Open |

### CI / docs / process

| ID | Issue | Where | Fix | Status |
|----|-------|-------|-----|--------|
| M-32 | GitHub CI entirely commented out; README and package docs still describe CI on PRs; email-template `check` job also disabled | `.github/workflows/ci.yml`, `README.md`, `packages/email-templates/README.md` | Re-enable (add `httpx` for API tests) or update docs | Open |
| M-33 | Docs still say migrations “through **022**”; repo has **023** | `docs/engineering/README.md`, `platform-architecture.md`, `building-the-app.md`, `initial-setup.md`, `development.md` | Bump to 023 | ✅ Fixed |
| M-34 | `scripts/verify-dev-migrations.sh` header/spot-checks stop at 021 | `scripts/verify-dev-migrations.sh` | Extend to 022–023 | ✅ Fixed |
| M-35 | `remediation-plan.md` is stale (lists idempotency as top gap, “migrations 001–020”, CI as healthy) | `docs/engineering/remediation-plan.md` | Refresh summary | ✅ Fixed |

---

## Low

| ID | Issue | Where |
|----|-------|-------|
| L-01 | `use_build_context_synchronously` infos across ~50 files (e.g. `app.dart` after `refreshSessionClaims`, `photo_source_sheet.dart`, `followers_screen.dart`) | mobile `lib/` |
| L-02 | Analyzer warnings: unnecessary `!` in `follower_home_composer.dart`, `owner_home_composer.dart`, `registry_screen.dart`; unused import in `home_teasers_section.dart` | mobile `lib/features/home`, `registry` |
| L-03 | Shell top bar refresh swallows errors (`catch (_) {}`) | `shell_top_bar.dart` |
| L-04 | FCM register/unregister failures swallowed | `core/notifications/push_notification_service.dart` |
| L-05 | Home summary wraps unknown errors with raw `$e` | `home_repository.dart` |
| L-06 | App Check debug token `print` for Maestro | `app_check_bootstrap.dart` |
| L-07 | Default API base URL baked in source; release builds must use `--dart-define-from-file` | `config/app_config.dart` |
| L-08 | Accessibility: semantics labels concentrated in shell/onboarding; many controls unlabeled (WCAG AA is the PRD baseline) | mobile |
| L-09 | Hardcoded UI strings vs `app_en.arb` (FR-SET-002) | e.g. `account_edit_screen.dart`, `home_screen.dart` |
| L-10 | No CORS middleware (fine for mobile-only; needs policy if a web client is added) | `services/api/main.py` |
| L-11 | `pytest` listed in production `requirements.txt` | `services/api/requirements.txt` |
| L-12 | Invitation preview 404 uses `detail="not_found"` string; accept errors use `{"error": …}` | `routers/invitation_accept.py` |
| L-13 | FCM tokens deleted on any multicast failure without checking error class | `worker/notifications.py` |
| L-14 | Poison/unknown Pub/Sub messages are logged and acked (204) with no metric | `worker/main.py` |
| L-15 | Dockerfiles run as root; Cloud Build only builds/pushes (no tests) | `services/*/Dockerfile`, `cloudbuild.yaml` |
| L-16 | Duplicate email template trees (intentional) but sync check is disabled with CI | `packages/email-templates`, `services/worker/email_templates` |

---

## Test coverage gaps

- **API:** ✅ `membership_ended` on home-summary/activity-events covered (`test_babies_home_membership.py`); still thin or no router tests for `events`, `registry`, `fun`, `data_export`, `search`, `notifications`, `onboarding`, `admin_system_announcements`.
- **Mobile:** `delete_account_screen_test.dart` only checks copy (no eligibility/delete/sign-out flow); no test for invite-accept result branches (H-07); upload tests cover headers only; login test is UI-only.
- **Worker:** export stuck-`running` and invite-email race paths untested.

---

## Verified as healthy (no action)

- Baby-scoped domain code consistently checks membership/ownership; repositories use parameterized SQL.
- Invite tokens: `secrets.token_urlsafe(32)` with SHA-256 at rest; signed URLs 900s TTL with content-length range; `safe_enqueue_*` keeps Pub/Sub failure from failing HTTP after commit.
- Deleted users → 401 `user_deleted`; mobile handles `user_deleted` / `membership_ended` in `api_client.dart`.
- Worker idempotency (`021_worker_idempotency`, `worker_delivery_log`) is implemented; channel-enum parity is guarded by test.
- Pagination caps in place (photos ≤100, activity/search ≤50).

---

## Suggested fix order

1. **Correctness / data safety:** H-02, H-03, H-07, H-08, M-17
2. **Pre-beta security:** H-01, H-04, H-05, H-06
3. **Validation + races:** M-02–M-06, M-11–M-13
4. **Infra + docs + CI:** M-18–M-22, M-32–M-35
5. **Mobile UX polish + lint:** M-23–M-31, Low items
