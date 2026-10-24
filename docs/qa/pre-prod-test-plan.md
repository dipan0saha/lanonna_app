# La Nonna — Pre-production manual QA test plan (Android emulator × dev)

| Field | Value |
|-------|--------|
| **Target** | `lanonna-dev` (API + worker + Cloud SQL per [operations.md](../engineering/operations.md)) |
| **Client** | Flutter Android app (`apps/mobile`), `flutter run --dart-define-from-file=flavors/dev.json` on an emulator |
| **Last derived from code** | 2026-10-23 (routes in `app_router.dart`, API routers under `services/api/src/lanonna_api/routers/`, worker `main.py`, migrations `001`–`044`) |
| **Related** | [pre-beta-qa.md](../engineering/pre-beta-qa.md) (focused smoke), [development.md](../engineering/development.md), [product/requirements.md](../product/requirements.md) |

This plan is **manual QA** before promoting dev-validated builds toward production. It is derived from implemented routes, domain permission checks, and worker handlers—not from wish-list features.

**Out of scope (removed from codebase):** Global baby-scoped search (`GET …/search`, shell magnifier) was removed from mobile and API ([open-gaps.md](../engineering/open-gaps.md)); do **not** expect a search icon in `HomeTopBar` (`home_top_bar.dart`). Historical pre-beta checklist items that mention search are obsolete.

**Terminology:** “Feed” in this app means **activity streams** (`activity_events`, home summary teasers, gallery “Recent Activity”, `/home/activity`)—not a separate “posts” product surface.

---

## 1. Priority definitions

| Priority | Meaning |
|----------|---------|
| **P0** | Launch blocker: auth, data loss, security (App Check enforce path), payments-adjacent registry integrity, push/deep links, hard delete, account delete storage cleanup, force-update gate |
| **P1** | Core product flows owners and followers rely on daily; role mistakes; broken uploads/thumbnails |
| **P2** | Polish, edge cases, empty states, theme consistency, dev-only Crashlytics tile, weekly digest scheduler |

---

## 2. Environment and prerequisites

Execute **once per test run** (record in run log at end).

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| ENV-001 | P0 | Deploy | GCP access to `lanonna-dev` | Confirm latest API and worker revisions deployed (`services/api/scripts/deploy.sh`, `services/worker/scripts/deploy.sh`); run `./scripts/apply-run-iam.sh` after worker | Cloud Run `api` and `worker` healthy; `GET /health` returns OK | `services/api/src/lanonna_api/main.py`, `services/worker/src/lanonna_worker/main.py` |
| ENV-002 | P0 | Migrations | Cloud SQL proxy + `DB_PASSWORD` from Secret Manager `db-lanonna-app-password` | Run `infra/db/apply_migrations.py`; then `./scripts/verify-migrations.sh` | All **44** migration files recorded in `schema_migrations` (through `044_drop_baby_profiles_deleted_at.sql` only after API/worker that no longer read `deleted_at` are deployed) | `infra/db/migrations/README.md`, `scripts/verify-migrations.sh` |
| ENV-003 | P0 | App build | Flutter SDK per `apps/mobile` | `cd apps/mobile && flutter run --dart-define-from-file=flavors/dev.json` on emulator; **disable** `DEV_AUTO_SIGN_IN_*` for auth/invite tests | App reaches onboarding or home against `flavors/dev.json` `API_BASE_URL` | `apps/mobile/flavors/dev.json`, `apps/mobile/lib/app.dart` |
| ENV-004 | P1 | App Check (dev) | Firebase App Check enabled | Pin `APP_CHECK_DEBUG_TOKEN` in `apps/mobile/maestro/local.env`, run `maestro/scripts/register-app-check-debug.sh`, rebuild debug; confirm logcat `Firebase App Check ready for API` | API requests include `X-Firebase-AppCheck` when token available; dev deploy default `APP_CHECK_ENFORCE=false` still accepts missing header | [pre-beta-qa.md](../engineering/pre-beta-qa.md), `services/api/scripts/deploy.sh` |
| ENV-005 | P0 | App Check (prod path rehearsal) | Optional pre-prod gate | Deploy API with `APP_CHECK_ENFORCE=true`; register emulator debug token; repeat signed-in home load | Without token, authenticated routes fail; with token, app works | `lanonna_api/app_check.py`, `main.py` `_app_check_deps` |
| ENV-006 | P1 | QA data | Firebase Auth users provisioned for QA (no real credentials in this doc) | Provision or use **QA owner test account**, **QA follower test account**, **QA co-owner test account** (e.g. `infra/db/provision_maestro_fixtures.py` target `qa`) | Owner has at least one baby; follower has membership on owner’s baby; co-owner optional third account | `infra/db/provision_maestro_fixtures.py` |
| ENV-007 | P2 | Automated sanity | CI green on release candidate commit | `flutter test`, `pytest` in `services/api` and `services/worker` | All green (does not replace manual plan) | `.github/workflows/ci.yml`, [development.md](../engineering/development.md) |

---

## 3. Test accounts (names only)

| Account label | Typical role | Notes |
|---------------|--------------|--------|
| **QA owner test account** | Owner on primary test baby | Completes owner onboarding; invites others |
| **QA follower test account** | Follower on owner’s baby | Used for permission-negative tests |
| **QA co-owner test account** | Second owner on same baby | Same API powers as owner (`role == owner`) |
| **QA throwaway account** | Disposable | Email verify, account delete, bot sign-up only |
| **QA dual-role account** (optional) | Owner on baby A, follower on baby B | Baby switcher + context reload |

Never document or share real passwords in tickets; use team secret store / Firebase console.

---

## 4. Cross-role permission matrix

Co-owner rows match **owner** (API stores `role: owner` for co-owner invites).

| Capability | Owner / co-owner | Follower | Primary enforcement |
|------------|------------------|----------|---------------------|
| View home, gallery list/detail, calendar, registry list, fun, birth announcement card | Yes | Yes | `require_membership` / `require_active_membership` |
| Upload gallery photo (`POST /v1/photos/init` purpose `gallery`) | Yes | **No** | `gallery.init_photo_upload` → `assert_owner_membership` |
| Upload event cover (`purpose: event_cover`) | Yes | **No** | Same; covers excluded from gallery list (`PhotoPurpose.GALLERY` filter) |
| Edit/delete photo caption; delete photo | Yes | **No** | `gallery.py` owner assertions on patch/delete |
| Squish photo; comment on photo | Yes | Yes | `toggle_squish`, `add_comment` with membership |
| Edit/delete **own** photo comment | Yes | Yes | `member_content_can_edit` |
| Delete **another’s** photo comment | Yes (owner) | **No** | `member_content_can_delete` + owner branch |
| Tag other babies on photo (“In this photo”) | Yes (owner, multi-baby) | Read-only tags | `set_photo_baby_tags` owner-only |
| Create/edit/delete calendar events | Yes | **No** | `calendar.py` `assert_owner_membership` on mutations |
| View event; RSVP; event comments | Yes | Yes | `require_membership` on read/RSVP/comments |
| Create/edit/delete registry items; shipping address | Yes | **No** | `registry.py` `assert_owner_membership` |
| Claim/purchase registry item | Yes | Yes | `claim_purchase` |
| Undo purchase | Owner **or** buyer | Buyer only if they claimed | `undo_purchase` |
| Name suggestions, gender/birthdate predictions | Yes | Yes | `fun.py` `require_membership` |
| Delete name suggestion | Owner **or** author | Author only for own | `member_content_can_delete` in fun domain |
| Batch invite; revoke/resend invites; members list; remove follower | Yes | **No** | `invitations.py`, `members.py`, `member_lifecycle.py` |
| Accept invite | N/A (invitee) | N/A | `invitation_accept.py` email match |
| Edit baby profile; hard delete baby (sole owner) | Yes | **No** | `babies.py`, `baby_delete.py` |
| Data export | Yes | **No** | `data_export.py` owner paths |
| Birth announcement create/edit | Yes | **No** | `announcement.py` `assert_owner_membership` on write |
| Birth announcement view/squish/comment | Yes | Yes | `fetch_announcement` membership |
| Leave baby (`POST …/leave`) | If `can_leave` | If `can_leave` | `member_lifecycle.leave_baby_profile` |
| Account delete | Self | Self | `profile.py` / `account_delete.py` |

### 4.1 Screen-level UI expectations (follower vs owner)

| Screen / route | Owner-only UI | Follower UI | Mobile implementation |
|----------------|---------------|-------------|------------------------|
| `/home` | Checklist, invite status, owner sections | Follower composer layout | `owner_home_composer.dart`, `follower_home_composer.dart` |
| `/gallery` | FAB upload | No FAB | `gallery_screen.dart` |
| `/calendar/event/create`, `…/edit` | Available | Hidden / blocked | `event_form_screen.dart`, API 403 if forced |
| `/registry/item/create`, `…/edit`, shipping | Available | Read + claim only | `registry_screen.dart`, `registry_item_form_screen.dart` |
| `/baby/:id/edit`, delete profile | Yes | No entry | `baby_edit_screen.dart` (`_isOwner`) |
| `/baby/:id/followers` | Invite/manage | **No route** (owner navigates from account) | `followers_screen.dart`, `account_screen.dart` |
| `/invite-family`, onboarding invite | Yes | N/A | `batch_invite_screen.dart` |
| `/gamification` | Full | Full (no owner-only tabs) | `fun_screen.dart` |
| `/profile` | Export baby data, manage followers link | No export | `account_screen.dart` |
| Announcement create | Yes | View card only | `announcement_create_screen.dart`, `announcement_card_screen.dart` |

---

## 5. Multi-account scenarios

| ID | Pri | Scenario | Accounts | Steps | Expected | Implementation |
|----|-----|----------|----------|-------|----------|----------------|
| MULTI-001 | P0 | Realtime push fan-out | QA owner (digest realtime, push on); QA follower | Follower uploads photo while owner app backgrounded | Owner receives FCM; tap opens gallery photo or inbox deep link | `worker/notifications.py`, `push_notification_service.dart`, `gallery.init_photo_upload` |
| MULTI-002 | P0 | Wrong-account invite accept | QA owner invite sent to follower email; sign in as **QA owner test account** | Open invite link | Wrong email screen; **Switch account** prefills login without email in URL | `onboarding_wrong_email_screen.dart`, `invite_accept_bootstrap_screen.dart` |
| MULTI-003 | P1 | Co-owner parity | QA co-owner test account | Accept co-owner invite; open calendar/registry/gallery upload | Same controls as primary owner | `invitations.py` `role: owner` |
| MULTI-004 | P1 | Max owners | QA owner + 2 co-owner invites pending | Batch invite third co-owner | `max_owners` / skipped row; no extra membership | `domain/invitations.py`, `batch_invite_result` UI |
| MULTI-005 | P1 | Remove follower | QA owner | Followers screen → remove QA follower | Follower loses access; `membership_ended` on baby-scoped API | `member_lifecycle.remove_member` |
| MULTI-006 | P1 | Follower leave | QA follower | Leave baby from account/baby card if `can_leave` | Membership ended; baby disappears from list | `members.py` `leave` |
| MULTI-007 | P1 | Dual-role switcher | QA dual-role account | Switch baby in shell switcher | Home/gallery/calendar/registry/fun reload for selected baby | `baby_switcher_sheet.dart`, `BabyContextReload` |
| MULTI-008 | P0 | Registry claim anonymity | QA follower claims item; QA owner views home activity | Claim registry item | Owners notified; activity shows anonymous claim for followers | `registry.claim_purchase`, activity types |
| MULTI-009 | P1 | Owner marks purchased | QA owner marks item purchased | Claim as owner | All members notified; activity names owner action | `REGISTRY_PURCHASED` activity |
| MULTI-010 | P0 | Sole owner delete baby | QA owner sole owner | Delete baby profile (two-step confirm) | Baby hard-deleted; follower sees gone; storage cleanup job | `delete_baby_profile_flow.dart`, `043_baby_hard_delete.sql`, `storage_cleanup` worker |

---

## 6. Authentication and session

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| AUTH-001 | P0 | Email sign-up | QA throwaway account email | Owner carousel → Sign up → email/password | Account created; routed to email verify | `onboarding_signup_screen.dart`, Firebase Auth |
| AUTH-002 | P0 | Email verification | AUTH-001 | Complete verify flow; tap **Verify my email** in message | Branded mail: subject **Verify your email for La Nonna**, sender **La Nonna**; link verifies | `onboarding_email_verify_screen.dart`, `auth_email_verification.dart`, Firebase templates |
| AUTH-003 | P0 | Email verify gate | Unverified user | Attempt to reach `/home` | Redirect to `/onboarding/email-verify` | `app_session.dart` `redirectFor` |
| AUTH-004 | P0 | Email/password sign-in | QA owner test account | Login with email/password | Reaches home or onboarding step per server status | `onboarding_login_screen.dart`, `AuthRepository` |
| AUTH-005 | P0 | Google sign-in | Google account on emulator | Tap Google on login/signup | Firebase Google auth; profile completion if needed | `onboarding_login_screen.dart`, `auth_repository.dart` |
| AUTH-006 | P0 | Password reset | Known account | Forgot password → email | Branded **Reset your password for La Nonna** | `forgot_password_dialog.dart` |
| AUTH-007 | P1 | Sign out | Signed in | Settings/account sign out | Session cleared; local caches wiped; onboarding/login | `session_cleanup.dart`, `AuthRepository.signOut` |
| AUTH-008 | P0 | JWT to API | Signed in | Use app normally | Authorized API calls; 401 clears session | `api_client.dart`, `auth` middleware |
| AUTH-009 | P2 | Legal links | Onboarding | Open Terms / Privacy | `/legal/terms`, `/legal/privacy` render | `legal_document_screen.dart`, `app_router.dart` |
| AUTH-010 | P1 | Desktop verify continue | Email link on desktop | After verify, `https://lanonna-dev.firebaseapp.com/email-verified` | Hosting page loads (not 404); phone **Continue** on verify screen | `hosting/`, `auth_action_app_link.dart` |

---

## 7. Biometric sign-in and app lock (30 s grace)

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| BIO-001 | P0 | Enable biometrics | Emulator with biometrics enrolled | Settings → biometric tile on | Enrollment + `PATCH /v1/profile` `biometric_unlock_enabled: true` + `POST /v1/me/biometric-credentials` | `biometric_unlock_settings_tile.dart`, `biometric_auth.py` |
| BIO-002 | P0 | App lock cold start | BIO-001; signed in; `canAccessMainApp` | Kill app; relaunch | Full-screen lock; unlock succeeds | `biometric_app_lock.dart`, `biometric_app_lock_policy.dart` |
| BIO-003 | P0 | Resume grace **&lt; 30 s** | BIO-001 | Background app &lt; 30 s; resume | **No** lock overlay | `app_config.dart` `biometricAppLockResumeGracePeriod = 30s` |
| BIO-004 | P0 | Resume grace **≥ 30 s** | BIO-001 | Background ≥ 30 s; resume | Lock engages | `biometric_app_lock_policy.dart` `biometricAppLockShouldEngageOnResume` |
| BIO-005 | P0 | No lock on onboarding | BIO-001; navigate to onboarding path | Open invite accept while signed in | Lock does not block onboarding routes | `biometric_app_lock_policy.dart` `isOnboardingPath` |
| BIO-006 | P0 | Sign in with biometrics after logout | BIO-001; log out | Login screen **Sign in with biometrics** | Challenge → `POST /auth/biometric/sign-in` → home | `biometric_sign_in_service.dart`, `onboarding_login_screen.dart` |
| BIO-007 | P1 | Disable biometrics | BIO-001 | Toggle off in Settings | No lock on resume; CTA hidden; credentials revoked on server | `profile.py` revoke on `biometric_unlock_enabled: false` |
| BIO-008 | P1 | App Check on biometric routes | APP_CHECK enforce on | Biometric enroll/sign-in | Requires App Check on `/v1/me/biometric-credentials`, `/auth/biometric/*` | `biometric_auth.py` `dependencies=[Depends(require_app_check)]` |

---

## 8. Onboarding (owner, follower, co-owner)

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| ONB-001 | P1 | Owner carousel | Logged out | Walk carousel **Next** | Art, caption band, dots; lands signup/login | `owner_carousel_screen.dart` |
| ONB-002 | P0 | Complete profile | Verified email | Fill display name, optional Mother/Father pills, demographics | `PATCH /v1/profile`; advance to create baby | `onboarding_complete_profile_screen.dart` |
| ONB-003 | P0 | Create baby (onboarding) | ONB-002 | Create expecting baby (gender pills, optional photo) | `POST /v1/babies`; owner membership | `onboarding_create_baby_screen.dart`, `create_baby_screen.dart` |
| ONB-004 | P0 | First moment / milestones | ONB-003 | First moment presets + name tags; submit | `POST …/onboarding/first-moment` seeds events/registry/names | `onboarding_first_moment_screen.dart`, `babies.py` `first_moment_seed`, `onboarding.seed_first_moment` |
| ONB-005 | P1 | Revise create baby | ONB-004 | **Back** from first moment → edit baby → save | PATCH baby, no duplicate POST | `create_baby_mode.dart`, `owner_onboarding_baby_phase.dart` |
| ONB-006 | P1 | Batch invite onboarding | ONB-004 | Owner invite step; send follower + co-owner rows | `POST …/invitations/batch`; emails queued | `batch_invite_screen.dart` `BatchInviteMode.onboarding` |
| ONB-007 | P0 | Follower carousel + accept | Pending follower invite token | Follower path: carousel → login → accept | Membership `follower`; confirm relationship if prompted | `follower_carousel_screen.dart`, `invitation_accept.py` |
| ONB-008 | P0 | Co-owner welcome | Co-owner invite | Co-owner path → welcome → home **without** owner create-baby | `can_access_main_app` true via invite | `onboarding_coowner_welcome_screen.dart`, `app_session_redirect_test.dart` |
| ONB-009 | P1 | Session offline | Airplane mode at cold start | Launch signed in | `/session-offline` when no cached onboarding status | `session_offline_screen.dart`, `app_session.dart` |
| ONB-010 | P1 | Cached status stale | Signed in; API down after prior success | Use app | Stale banner/behavior per design; reconnect refreshes | `app_session.dart` `statusStale` |

---

## 9. Invitations and deep links

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| INV-001 | P0 | HTTPS invite link | Pending invite token | `adb shell am start -a VIEW -d 'https://lanonna-dev.firebaseapp.com/invite?token=…'` | Opens `/invite-accept?token=…` | `invite_app_link.dart`, `app_link_bootstrap.dart` |
| INV-002 | P0 | Custom scheme | Valid token | `lanonna://app/invite-accept?token=…` | Same bootstrap | `invite_app_link.dart` |
| INV-003 | P0 | Preview without auth | Token | `GET /v1/invitations/preview?token=` (curl) **without** App Check | 200 preview JSON | `invitation_accept.py` (no App Check on preview) |
| INV-004 | P0 | Accept requires auth + App Check | Signed in QA follower | Accept invite matching email | 200; baby in list | `POST /v1/invitations/accept` |
| INV-005 | P1 | Pending token resume | Kill app after link | Relaunch without link | `pendingInviteToken` resumes flow | `onboarding_coordinator.dart`, [development.md](../engineering/development.md) |
| INV-006 | P1 | Revoke invite | QA owner | Followers → revoke pending | `DELETE …/invitations/{id}`; link invalid | `invitations.py` |
| INV-007 | P1 | Resend invite | Pending invite | Resend | Worker `send_invite_email`; delivery status fields update | `invitations.py`, `worker/invite_email.py` |
| INV-008 | P1 | Invite email branding | Mailjet delivery | Open invite email | HTTPS link; co-owner copy mentions co-owner; follower does not | `worker/email_templates/invite_v1.html`, `invite_email_copy.py` |
| INV-009 | P1 | Membership check | QA owner | Batch invite UI checks existing email | `GET …/membership-check` warnings | `invitations.py` |
| INV-010 | P1 | From-home batch invite | Onboarded owner | Home → invite family (`/invite-family`) | Same batch API; Mother/Father co-owner presets | `app_routes.dart` `inviteFamily`, `relationship_preset.dart` |

---

## 10. Baby profile lifecycle

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| BABY-001 | P0 | In-app create baby | QA owner | `/baby/create` | New baby; switcher lists both | `create_baby_screen.dart` `CreateBabyMode.inApp` |
| BABY-002 | P0 | Edit baby | Owner | `/baby/:id/edit` name, dates, lifecycle, avatar | `PATCH /v1/babies/{id}` | `baby_edit_screen.dart` |
| BABY-003 | P0 | Announce arrival (born) | Expecting owner | Home announce sheet or edit lifecycle to born + actual date | `announce_arrival` path on PATCH | `announce_arrival_sheet.dart`, `babies.py` |
| BABY-004 | P0 | Hard delete baby | **Sole** active owner | Delete profile two-step confirm | `DELETE /v1/babies/{id}`; data gone for all members | `delete_baby_profile_flow.dart`, `baby_delete.py`, migration `043` |
| BABY-005 | P0 | Delete blocked with co-owner | Baby with co-owner | Delete attempt on baby | UI blocks with co-owner message | `baby_edit_screen.dart`, `canDeleteProfile` |
| BABY-006 | P1 | Follower cannot edit | QA follower | Deep link to edit URL | No UI or API 403 | `baby_edit_screen.dart` `_isOwner` |

---

## 11. Home hub and activity feed

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| HOME-001 | P0 | Home summary load | Member | Open `/home` | `GET …/home-summary` renders owner/follower sections | `home_screen.dart`, `domain/home.py` |
| HOME-002 | P0 | Baby switcher | Multi-baby account | Switch baby in top bar | Title updates; tabs reload context | `shell_top_bar.dart`, `selected_baby_store.dart` |
| HOME-003 | P1 | Home tab re-tap refresh | On home | Tap Home nav again | Refresh signal reloads | `main_shell_screen.dart`, `HomeRefreshSignal` |
| HOME-004 | P1 | Activity feed | Owner | Open `/home/activity?babyId=` | Paginated `activity-events` `scope=all` | `home_activity_screen.dart`, `babies.py` |
| HOME-005 | P1 | Gallery activity scope | Photos with comments/squishes | Gallery → Recent Activity | `scope=gallery` events | `gallery_screen.dart`, `list_activity_events` |
| HOME-006 | P1 | System announcements | Dev SQL banner rows | Owner vs follower home | Targeted banners; dismiss persists | `home_system_announcements_section.dart`, `system_announcements` repo |
| HOME-007 | P2 | Shell chrome | Tab roots | Confirm top bar: add baby, invite, switcher, bell, avatar | Matches FR-SHELL-001; **no** search icon | `home_top_bar.dart`, `emulator_testing/README.md` |
| HOME-008 | P1 | Teaser deep link | Home photo teaser | Tap | Navigates to `/gallery/photo/:id` on root stack | `deep_link_navigation.dart` |

---

## 12. Gallery and media pipeline

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| GAL-001 | P0 | Upload encode | Owner | Pick large image; upload | Client display encode ≤ 2 MB; no oversize error | `display_encode.dart`, `display_photo_upload.dart` |
| GAL-002 | P0 | Signed PUT + finalize | GAL-001 | Complete upload | GCS object; worker thumbnail; photo `ready` | `photos_init`, `worker/thumbnails.py` `process_gcs_finalize` |
| GAL-003 | P0 | Thumbnail in grid | GAL-002 | Open gallery | Thumb URL loads; badges for comment/squish counts &gt; 0 | `gallery_screen.dart`, `sign_media` |
| GAL-004 | P1 | Sort modes | Multiple photos | `/gallery`, `/gallery/recent`, `/gallery/favorites` | Sort query matches API | `app_router.dart`, `list_photos` `sort` |
| GAL-005 | P0 | Photo detail | Member | Open photo | Display signed URL; uploader name | `photo_detail_screen.dart`, `get_photo_detail` |
| GAL-006 | P1 | Disk cache / URL TTL | GAL-005 | Reopen photo after scroll away | Fast load; after ~15 min stale, refresh recovers | [pre-beta-qa.md](../engineering/pre-beta-qa.md), `media_urls` 900s TTL |
| GAL-007 | P0 | Squish | Follower | Tap squish | Count updates; activity + optional notify | `POST …/squish`, `toggle_squish` |
| GAL-008 | P0 | Comments | Member | Add comment; edit own; delete own | Owner can delete others’ | `photos.py` comment routes, `content_permissions.py` |
| GAL-009 | P1 | Caption edit | Owner | Edit caption | PATCH photo | `patch_caption` owner-only |
| GAL-010 | P0 | Delete photo | Owner | Delete | 204; removed from gallery | `remove_photo` |
| GAL-011 | P1 | Baby tags | Owner multi-baby | Tag pills on detail | `PUT …/tags` | `photo_detail_screen.dart`, migration `019` |
| GAL-012 | P0 | Follower upload blocked | Follower | Attempt upload if UI exposed | API 403 on init | `init_photo_upload` |
| GAL-013 | P0 | Offline upload | Airplane mode | Start upload | Immediate offline error, no hang | `api_client.dart`, `offline_banner.dart` |

---

## 13. Calendar and event covers

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| CAL-001 | P0 | Month grid + today | Member | Open `/calendar` | Today highlighted; day selection lists events | `calendar_screen.dart`, `calendar_display.dart` |
| CAL-002 | P0 | Create event | Owner | `/calendar/event/create` | `POST …/events` | `event_form_screen.dart`, `events.py` |
| CAL-003 | P0 | Event detail + RSVP | Follower | Open event; set RSVP | `PUT …/rsvp` | `event_detail_screen.dart`, `rsvp_status.dart` |
| CAL-004 | P0 | Event comments | Member | Add/edit/delete per matrix | Same rules as photo comments | `events.py`, `event_comment_thread.dart` |
| CAL-005 | P1 | Edit/delete event | Owner | Edit route | PATCH/DELETE | `event_form_screen.dart` |
| CAL-006 | P1 | AI suggestions | Owner | `/calendar/ai-suggestions` | Static catalog; create with `catalog_suggestion_id` | `event_ai_suggestions_screen.dart`, migration `018` |
| CAL-007 | P1 | Upcoming list | Member | `/calendar/upcoming` | Lists future events | `calendar_upcoming_screen.dart` |
| CAL-008 | P0 | Event cover not in gallery | Owner | Create event with cover photo | Cover `purpose=event_cover`; **absent** from gallery grid | `event_cover_uploader.dart`, `PhotoPurpose`, integration test #315 |
| CAL-009 | P1 | Delete cover photo | Owner | Delete cover image | Event `cover_photo_id` null (`ON DELETE SET NULL`) | migration `040` |

---

## 14. Registry

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| REG-001 | P0 | List items | Member | `/registry` | Needed vs purchased sections | `registry_screen.dart`, `list_items` |
| REG-002 | P0 | Create item | Owner | `/registry/item/create` | POST item | `registry_item_form_screen.dart` |
| REG-003 | P1 | AI suggestions | Owner | `/registry/ai-suggestions` | Add from catalog | `registry_ai_suggestions_screen.dart` |
| REG-004 | P0 | Claim item | Follower | Claim | Single purchase row; second claim fails | `claim_purchase` |
| REG-005 | P0 | Owner mark purchased | Owner | Mark purchased | Notifies all members | `REGISTRY_PURCHASED` |
| REG-006 | P1 | Undo purchase | Buyer or owner | Undo | Purchase removed | `undo_purchase` |
| REG-007 | P1 | Edit blocked when purchased | Owner | Edit purchased item | API error `REGISTRY_ITEM_PURCHASED` | `patch_item` |
| REG-008 | P1 | Shipping address | Owner | `/registry/shipping-address` | Structured fields saved on baby profile | `registry_shipping_address_screen.dart`, migration `023` |
| REG-009 | P2 | Priority chip | Owner | Set priority 1–5 | UI chip + API | `registry_priority_chip.dart` |

---

## 15. Fun / gamification (`/gamification`)

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| FUN-001 | P1 | Name suggestions | Member | Add name; like | `POST/GET …/fun/names`, like endpoint | `fun_screen.dart`, `fun.py` |
| FUN-002 | P1 | Delete name | Owner or author | Delete suggestion | Permissions per matrix | `DELETE …/names/{id}` |
| FUN-003 | P1 | Gender prediction | Member | Vote | `PUT …/predictions/gender` | `fun.py` |
| FUN-004 | P1 | Birthdate prediction | Member | Vote | `PUT …/predictions/birthdate` | `fun.py` |
| FUN-005 | P2 | Family insight card | Home with votes | Home shows rich insight when votes exist | Owner/follower home composers | `home_summary.dart`, product FR-HOME |

---

## 16. Birth announcement (keepsake)

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| ANN-001 | P1 | View card | Born baby member | `/baby/:id/announcement` | GET announcement + signed `photo_display_url` | `announcement_card_screen.dart` |
| ANN-002 | P1 | Create/edit | Owner | `/baby/:id/announcement/create` | PUT/PATCH announcement | `announcement_create_screen.dart`, `announcement.py` |
| ANN-003 | P1 | Squish + comments | Member | Interact on card | Toggle squish; comments | `announcements.py` squish/comments routes |
| ANN-004 | P2 | Share | Owner | Share action if shown | Share sheet works | `announcement_share.dart` |

---

## 17. Account, settings, export, delete

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| ACC-001 | P0 | Account screen | Signed in | `/profile` | Profile card, babies, storage, engagement | `account_screen.dart`, `GET /v1/me/account` |
| ACC-002 | P1 | Edit profile | Signed in | `/account/edit` | PATCH profile fields + avatar URL normalization | `account_edit_screen.dart` |
| ACC-003 | P1 | Settings | Signed in | `/settings` | Biometric tile, notifications link, help mailto | `settings_screen.dart` |
| ACC-004 | P0 | Notification preferences | Signed in | `/account/notification-preferences` | PATCH prefs channels + digest | `notification_preferences_screen.dart`, `profile.py` |
| ACC-005 | P0 | Data export | Owner | `/account/export` → start job | Job → **ready**; download JSON/ZIP; photo URLs https 7-day note | `baby_data_export_screen.dart`, `data_export.py`, `worker/baby_data_export.py` |
| ACC-006 | P0 | Account delete | QA throwaway sole owner | `/account/delete` confirm | User deleted; babies hard-deleted; `storage_cleanup` jobs | `delete_account_screen.dart`, `account_delete.py`, migration `042` |
| ACC-007 | P0 | Account delete co-owner case | Owner with co-owner baby | Delete account | Baby remains; co-owner retains ownership | `delete_account_screen.dart` copy + domain |
| ACC-008 | P1 | Followers management | Owner | `/baby/:id/followers` | List members + pending invites; remove | `followers_screen.dart` |
| ACC-009 | P2 | Crashlytics dev | Dev flavor | Settings test crash | Non-fatal/crash reported in Firebase | `crashlytics_dev_tools.dart`, [mobile-prod-flavor-and-crashlytics.md](../engineering/mobile-prod-flavor-and-crashlytics.md) |

---

## 18. Notifications inbox and push

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| NOT-001 | P0 | Unread dot | Unread rows | Shell bell | Dot when count &gt; 0 | `notifications_repository.dart`, `GET …/notifications/unread-count` |
| NOT-002 | P0 | Inbox paging | Many notifications | `/notifications/inbox` scroll | Offset paging; structured `notification_kind` + params render | `notifications_inbox_screen.dart`, `notifications.py` |
| NOT-003 | P0 | Mark read | User | Tap row / mark read | `PATCH …/notifications/{id}/read` | `notifications_repository.dart` |
| NOT-004 | P1 | Mark all read | User | Mark all | `POST …/notifications/read-all` | `notifications.py` |
| NOT-005 | P0 | Deep link from row | Row with `deep_link` | Tap | `navigateAppDeepLink` switches baby if needed | `deep_link_navigation.dart`, `inbox_notification_row.dart` |
| NOT-006 | P0 | FCM token register | Push permission granted | Launch app signed in | `PUT …/device-tokens` | `push_notification_service.dart` |
| NOT-007 | P0 | FCM data payload | MULTI-001 | Receive push | `deep_link` + `baby_profile_id` in data | `test_notifications_fcm_data.py` |
| NOT-008 | P1 | Channel toggles | User disables gallery channel | Upload photo | No push for disabled channel | `notify_*` channel filters |
| NOT-009 | P1 | Dismiss system announcement | Home banner | Dismiss | `POST …/system-announcements/{id}/dismiss` | `home_system_announcements_section.dart` |

---

## 19. App version / force update

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| VER-001 | P0 | Version check | Dev DB row in `app_versions` | Launch app | `GET /v1/app/version?platform=android` | `app_config.py`, `app_version_gate.dart` |
| VER-002 | P0 | Force update block | Set `minimum_version` above installed | Cold start | Full-screen block with store link | `AppVersionBlockScreen` |
| VER-003 | P1 | Below minimum patch semantics | Compare `1.0.1+5` vs `1.0.0` | Unit sanity | Not blocked when current ≥ minimum | `app_version_check.dart` |

---

## 20. Offline, errors, and empty states

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| OFF-001 | P0 | Tab offline | Airplane mode | Open Gallery/Calendar/Registry/Fun | Cached baby title; error + Try again via `AsyncTabBody` | `tab_load_kind.dart`, `app_offline_wrapper.dart` |
| OFF-002 | P1 | Refresh failure snackbar | Online → flaky | Pull refresh fails | Prior content remains; snackbar | `home_screen.dart` |
| OFF-003 | P1 | Empty gallery | New baby | Open gallery | Empty state component | `app_empty_state.dart` |
| OFF-004 | P1 | Empty followers | No followers | Followers screen | `followersEmpty` copy | `followers_screen.dart` |
| OFF-005 | P1 | API error mapping | Force 403 membership ended | Open baby tab | User-visible message; not raw exception | `api_error_message.dart` |
| OFF-006 | P1 | Membership ended | Removed follower | Deep link to old baby photo | Graceful error / redirect | `MemberLifecycleError` |

---

## 21. Theme and UX consistency

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| UX-001 | P2 | Light theme only | Signed in | Settings | No dark mode toggle | [product/requirements.md](../product/requirements.md) §5 |
| UX-002 | P2 | Brand tokens | Onboarding + home | Visual pass | Sage/peach tokens, Inter + Baloo 2, pill buttons 52px | `la_nonna_theme.dart`, `app_colors.dart` |
| UX-003 | P2 | Subpage inset ~26px | Settings, followers, registry forms | Compare horizontal padding | Matches `AppMetrics.subpageScrollPadding` | `prototype_subpage_scaffold.dart` |
| UX-004 | P2 | No Material black chips | Product surfaces | Scan chips | Custom `AppChip` / pills | `check-no-material-chips.sh` |
| UX-005 | P2 | Subpage back stack | From inbox open photo detail | Back | Returns to inbox not home | `detail_back_stack_test.dart` pattern |

---

## 22. Deep links and navigation (in-app)

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| DL-001 | P0 | normalize `/account` | Push/inbox | Open `/account` | Maps to `/profile` | `deep_link_navigation.dart` |
| DL-002 | P0 | Calendar event | Notification | `/calendar/event/{id}` | Event detail on root navigator | `app_router.dart` |
| DL-003 | P0 | Settings path | External | `/settings` | Settings screen | `deep_link_navigation_test.dart` |
| DL-004 | P1 | Invite family | Home CTA | `/invite-family` | Batch invite from home | `app_routes.dart` |
| DL-005 | P1 | Tab vs push | From inbox to gallery photo | `push` not `go` for non-tab | Back stack correct | `navigateAppDeepLink` |

---

## 23. Backend-only and operational checks

Run on **lanonna-dev** during pre-prod (no emulator required). Complement with [operations.md](../engineering/operations.md).

| ID | Pri | Check | Steps | Expected | Implementation |
|----|-----|-------|-------|----------|----------------|
| BE-001 | P0 | DLQ empty after export | After ACC-005 export | `gcloud pubsub subscriptions pull lanonna-async-commands-dlq-pull --limit=10` | No unprocessed failures | `operations.md` DLQ section |
| BE-002 | P0 | Thumbnail worker | Upload photo in app | GCS finalize message; worker logs; `photos.status=ready` | `process_gcs_finalize` |
| BE-003 | P0 | Invite email worker | Send invite | Pub/Sub `send_invite_email`; Mailjet delivery; `email_delivery_status` | `invite_email.py` |
| BE-004 | P1 | Expire invitations cron | Wait or trigger scheduler | `POST /cron/expire-pending-invitations` marks stale invites | `worker/main.py`, `invite_cleanup.py` |
| BE-005 | P1 | Weekly digest cron | Trigger `POST /cron/weekly-notification-digest` | Digest messages enqueued for eligible users | `process_weekly_notification_digest` |
| BE-006 | P0 | Storage cleanup sweep | After ACC-006 or BABY-004 | `storage_cleanup` jobs complete; GCS objects removed | `storage_cleanup.py`, `042_storage_cleanup_jobs.sql` |
| BE-007 | P1 | Export idempotency | Retry export Pub/Sub | Job row prevents duplicate archives | `021_worker_idempotency.sql`, `baby_data_export.py` |
| BE-008 | P1 | Event cover notify skip | Upload event cover | No gallery “photo ready” fan-out for `event_cover` | `worker/db.py` `PhotoPurpose.EVENT_COVER` |
| BE-009 | P2 | Admin system announcements | Admin API key | CRUD via `/v1/admin/system-announcements` | `admin_system_announcements.py` |
| BE-010 | P0 | Migration 044 gate | Before applying 044 | API/worker builds without `deleted_at` reads deployed | `044_drop_baby_profiles_deleted_at.sql` README note |
| BE-011 | P1 | Infra smoke script | `SMOKE_TEST_PASSWORD` set | `./scripts/infra-smoke-display-upload.sh` | End-to-end upload path green | `scripts/infra-smoke-display-upload.sh` |
| BE-012 | P1 | Pub/Sub max attempts | Inspect subscription | `pubsub_max_delivery_attempts = 12` matches worker env | `infra/terraform` `pubsub.tf`, `worker/config.py` |

---

## 24. Regression bundle (quick P0 smoke path)

Minimum path if time-boxed (≈2–3 hours): **ENV-001–003**, **AUTH-004**, **BIO-002–004**, **GAL-001–003**, **INV-001**, **MULTI-001**, **CAL-008**, **REG-004**, **NOT-005–007**, **ACC-005–006**, **VER-001**, **BE-001–003**.

---

## 25. Run log template

| Field | Value |
|-------|--------|
| Date | |
| Tester | |
| Emulator API level / device ID | |
| App version (`pubspec.yaml`) | |
| API revision | |
| Worker revision | |
| Migrations verified (`verify-migrations.sh`) | |
| `APP_CHECK_ENFORCE` | |
| DLQ peek (`BE-001`) | |
| P0 failed IDs | |
| P1 failed IDs | |
| Sign-off (ready for prod deploy rehearsal) | |

---

## 26. Additional cases (membership, registry delete, favorites)

| ID | Pri | Area | Preconditions | Steps | Expected result | Implementation |
|----|-----|------|---------------|-------|-----------------|----------------|
| MEM-001 | P1 | Leave baby (follower) | QA follower with `can_leave` true | Account or baby card → leave | `POST …/leave`; baby removed from list | `members.py`, `account_baby_profiles_card.dart` |
| MEM-002 | P1 | Leave blocked sole owner | Sole owner without co-owner | Attempt leave | UI explains add co-owner / delete baby / delete account | `member_lifecycle.py`, l10n sole-owner copy |
| MEM-003 | P1 | Remove member | QA owner | Followers → remove follower | `DELETE …/members/{uid}` | `followers_screen.dart` |
| REG-010 | P1 | Delete registry item | Owner; unpurchased item | Delete from registry UI | `remove_item` | `registry_screen.dart`, `registry.py` |
| GAL-014 | P1 | Favorites sort | User squishes photo | Open `/gallery/favorites` | Photo appears in favorites sort | `list_photos` `sort=favorites`, squish toggle |
| GAL-015 | P1 | Upload poll timeout | Slow worker | Upload; wait past poll limit | User-visible error (not silent spinner forever) | `gallery_screen.dart` poll timeout (M-59 partial) |
| FUN-006 | P2 | Squish as “reaction” | Member | Squish gallery photo + announcement | Count increments (product “reaction” = squish, not separate emoji set) | `toggle_squish`, announcement squish routes |
| ONB-011 | P1 | Follower invite screen | Logged out with invite context | `/onboarding/follower/invite` | Explains invite; routes to login/signup | `onboarding_follower_invite_screen.dart` |
| ONB-012 | P1 | Co-owner invite screen | Co-owner token path | `/onboarding/coowner/invite` | Co-owner specific copy | `onboarding_coowner_invite_screen.dart` |
| ONB-013 | P1 | Confirm relationship | Follower accept | `/onboarding/follower/confirm-relationship` | Relationship label saved | `onboarding_confirm_relationship_screen.dart` |
| NOT-010 | P1 | Weekly digest (backend) | User with `notification_digest=weekly` | Run BE-005 cron | Inbox/push digest rows (`notification_type=digest`) | `process_weekly_notification_digest`, migration `014` |
| ACC-010 | P1 | Log out keeps biometric sign-in; turning it off removes it | BIO-006 | 1) Log out after biometric sign-in. 2) Settings → turn **Biometric sign-in & unlock** off, then log out | 1) Login screen still offers **Sign in with biometrics** and it signs in (enrollment kept by design). 2) No biometric option on login; after password login the switch is off and must be enrolled again | `biometric_sign_in_service.dart` (`clearLocalEnrollment`), `auth_session_service.dart`, `settings_screen.dart` |

---

## 27. Route and API index (reference)

**Mobile routes:** `apps/mobile/lib/core/router/app_router.dart`, `onboarding_routes.dart`, `gallery_routes.dart`, `calendar_routes.dart`, `registry_routes.dart`, `app_routes.dart`.

**API routers:** `profile`, `biometric_auth`, `notifications`, `onboarding`, `babies`, `invitations`, `members`, `invitation_accept`, `app_config`, `photos` (+ baby photos), `events`, `registry`, `fun`, `announcements`, `data_export`, `admin_system_announcements` — registered in `services/api/src/lanonna_api/main.py`.

**Worker ingress:** `POST /pubsub/push` types `send_invite_email`, `notify_fan_out`, `notify_user`, `expire_pending_invitations`, `weekly_notification_digest`, `sweep_storage_cleanup_jobs`, `storage_cleanup`, `baby_data_export`, plus GCS finalize payloads — `services/worker/src/lanonna_worker/main.py`.
