# La Nonna — data inventory (code-derived)

**Purpose:** Support privacy policy, terms of service, Google Play Data safety, and legal review.  
**Source:** Repository state at documentation time; derived from mobile app, API, worker, database migrations, and infrastructure code.  
**Not legal advice:** Items marked **Owner/lawyer review** need professional judgment (e.g. COPPA, GDPR child data, international transfers).

**Placeholders used in public-facing drafts:** `{{CONTACT_EMAIL}}`, `{{COMPANY_OR_DEVELOPER_NAME}}`, `{{DOMAIN}}`, `{{EFFECTIVE_DATE}}`, `{{JURISDICTION}}`.

---

## 1. Product summary

La Nonna is a family circle app for expecting and new parents. Account holders (typically adults) create **baby profiles**, invite **followers**, share **photos**, use a shared **calendar**, **registry**, **name/prediction games**, and **birth announcements**. Android package: `com.lanonna.lanonna`. Backend: FastAPI on Google Cloud Run, PostgreSQL on Cloud SQL, asynchronous work via Pub/Sub and a Python worker.

---

## 2. Data categories and code references

### 2.1 Account and identity (adult users)

| Data | Why collected | Where stored | Code references |
|------|---------------|--------------|-----------------|
| Firebase Authentication UID | Primary account key; API auth | `app_users.firebase_uid`; Firebase Auth | `infra/db/migrations/001_app_users.sql`; `services/api/src/lanonna_api/repositories/users.py` |
| Email | Sign-in (email/password), profile, invites matching | `app_users.email`; Firebase Auth; invite rows | `001_app_users.sql`; `003_user_onboarding_invitations.sql`; `apps/mobile/lib/core/auth/auth_repository.dart` |
| Display name | Shown to family circle | `app_users.display_name` | `003_user_onboarding_invitations.sql`; `schemas/profile.py` |
| Avatar image URL | Profile photo | `app_users.avatar_url`; GCS `avatars/users/{uid}/…` | `005_user_avatar_url.sql`; `services/api/src/lanonna_api/storage.py` |
| Phone (optional) | User-provided profile | `app_users.phone` | `022_user_profile_demographics.sql`; `schemas/profile.py` |
| Birth date (optional) | User-provided profile | `app_users.birth_date` | `022_user_profile_demographics.sql` |
| Country code, postal code (optional) | User-provided profile | `app_users.country_code`, `postal_code` | `022_user_profile_demographics.sql` |
| Terms acceptance timestamp | Record of accepting terms | `app_users.terms_accepted_at` | `022_user_profile_demographics.sql`; onboarding `accept_terms` in `apps/mobile/lib/features/onboarding/data/onboarding_repository.dart` |
| Owner onboarding completion | Product flow | `app_users.owner_onboarding_completed_at` | `003_user_onboarding_invitations.sql` |
| Last seen (activity) | Session freshness; throttled DB write | `app_users.last_seen_at` | `030_app_users_last_seen.sql`; `repositories/users.py` |
| Notification preferences | Push/in-app notification behavior | `app_users.notification_digest`, `push_notifications_enabled`, `email_digest_enabled`, per-channel `notify_*` | `011_notifications_and_prefs.sql`, `016_notification_channels.sql`; `routers/profile.py` |
| Biometric unlock preference | Optional app lock | `app_users.biometric_unlock_enabled` | `035_app_users_biometric_unlock.sql` |
| Account tombstone | Deleted account marker | `app_users.deleted_at`; cleared `email`, `avatar_url`; `display_name` → `"Deleted user"` | `012_export_jobs_and_account_delete.sql`; `repositories/account_delete.py` |

**Authentication methods (mobile):**

- Email/password and email verification (Firebase Auth).
- Google Sign-In → Firebase credential (`apps/mobile/lib/core/auth/auth_repository.dart`).
- Biometric sign-in: device key pair; server stores **public key only** (`041_biometric_credentials.sql`; `routers/biometric_auth.py`; `biometric_signature` + `local_auth` in `pubspec.yaml`).

**Owner/lawyer review:** Tombstoned accounts may retain some non-cleared columns (e.g. phone, birth date) in Postgres while `email` is nulled — confirm retention and erasure obligations (`repositories/account_delete.py` only updates display name, email, avatar, `deleted_at`).

### 2.2 Children and baby-related data (about minors)

The app stores information **about babies/children** entered by adult account holders, not child accounts.

| Data | Why | Where | Code references |
|------|-----|-------|-----------------|
| Baby name (optional), gender, expected/actual birth dates, lifecycle (expecting/born) | Core profile | `baby_profiles` | `002_core_domain.sql`; `039_baby_name_nullable_gender_not_null.sql`; `schemas/babies.py` |
| Baby avatar | Profile image | `baby_profiles.avatar_url`; GCS `avatars/babies/{id}/…` | `013_baby_avatar_url.sql`; `storage.py` |
| Registry shipping address lines | Gift registry fulfillment | `baby_profiles.registry_shipping_*` | `023_registry_shipping_structured.sql` |
| Birth announcement fields | Keepsake (name, birth date/time, weight/length text, photo) | `birth_announcements` | `009_birth_announcements.sql` |
| Photos, captions, tags | Family gallery | `photos`, `photo_baby_tags`, GCS `display/`, `thumbnails/` | `002_core_domain.sql`, `007_gallery_calendar_social.sql`, `019_photo_baby_tags.sql`, `040_photo_purpose.sql` |
| Calendar events (title, description, location, video call URL) | Shared planning | `events` | `007_gallery_calendar_social.sql` |
| Name suggestions, votes, predictions | Social games | `name_suggestions`, `votes`, etc. | `008_registry_fun_social.sql` |
| Comments, RSVPs, “squish” reactions | Social engagement | `photo_comments`, `event_comments`, `event_rsvps`, `photo_squishes`, etc. | `007_gallery_calendar_social.sql`, `009_birth_announcements.sql` |

**Owner/lawyer review:**

- App is intended for **adults** (parents/family), not directed at children as users.
- Stored baby PII/photos may implicate **GDPR** (child data), **COPPA** (if US children under 13 are identifiable), and similar laws depending on `{{JURISDICTION}}` and audience.
- Clarify lawful basis, parental authority, and whether baby data requires additional consent or DPIA.

### 2.3 Family circle, invites, and followers

| Data | Why | Where | Code references |
|------|-----|-------|-----------------|
| Membership role (owner/follower), relationship label, join source | Access control | `baby_memberships` | `002_core_domain.sql`; `031_membership_joined_via.sql` |
| Invitee email, token hash, status, expiry | Invite flow | `invitations` | `003_user_onboarding_invitations.sql`; email delivery columns `027`–`028`, `034` |
| Activity feed entries | In-app history | `activity_events` | `006_home_activity.sql`; `038_structured_notification_activity_params.sql` |
| In-app notifications | User inbox | `notifications` | `011_notifications_and_prefs.sql`; `036`, `038` |

Invite emails are sent via **Mailjet** with template copy from `packages/email-templates/` (`invite_v1.txt`, `invite_v1.html`). Worker: `services/worker/src/lanonna_worker/invite_email.py`.

Firebase Hosting serves invite landing pages (`hosting/public/invite/index.html`; `hosting/firebase.json`).

### 2.4 Device and technical data

| Data | Why | Where | Code references |
|------|-----|-------|-----------------|
| FCM device token, platform | Push notifications | `device_tokens` | `014_device_tokens_and_digest.sql`; `apps/mobile/lib/core/notifications/push_notification_service.dart`; `PUT/DELETE /v1/me/device-tokens` |
| Firebase ID token | API authentication | Transmitted per request; validated server-side | `apps/mobile/lib/core/api/api_client.dart` |
| Firebase App Check token | Abuse reduction | Header `X-Firebase-AppCheck` | `firebase_app_check` in `pubspec.yaml`; API tests `api_client_app_check_test.dart` |
| Crashlytics user id | Crash debugging | Firebase Crashlytics (Firebase UID when signed in) | `crash_reporting_bootstrap.dart`; `firebase_crashlytics` |
| Crash stack traces / device state | Stability | Firebase Crashlytics | `firebase_crash_reporter.dart`; prod collection in `app_config.dart` |
| Biometric credential metadata | Passwordless sign-in | `biometric_credentials`, `biometric_sign_in_challenges` | `041_biometric_credentials.sql` |
| Connectivity state | Offline UX | Local only (`connectivity_plus`) | `pubspec.yaml` |
| Cached images | Performance | Local disk via `flutter_cache_manager` / `signed_image_cache.dart` | Cleared on sign-out via `session_cleanup.dart` |

**Not observed in Dart application code:** Firebase Analytics event logging (Crashlytics only for observability). Android `google-services.json` may enable Google SDK behaviors — **Owner/lawyer review** against Firebase/Google Play disclosures.

**“AI Suggestions” in UI:** Calendar/registry suggestions come from **bundled JSON catalogs** on device (`event_suggestions_catalog.dart`, `assets/calendar/event_suggestions.json`), not from a third-party generative AI API.

### 2.5 Photos and uploads

- User selects camera or library (`image_picker`; iOS `Info.plist` camera/photo usage strings).
- Images are re-encoded client-side: EXIF orientation applied, **remaining camera metadata dropped**, WebP/JPEG upload (`display_encode.dart`).
- Upload path: signed URL from API → PUT to GCS (`display_photo_upload.dart`, `storage.py`).
- Thumbnails generated by worker on GCS `OBJECT_FINALIZE` (`services/worker/src/lanonna_worker/thumbnails.py`).

### 2.6 Local storage on device (not server)

| Data | Mechanism | Cleared on sign-out/delete |
|------|-----------|----------------------------|
| Account identity cache (name, email, avatar URL) | `SharedPreferences` | `account_identity_store.dart`; `SessionCleanup` |
| Biometric enrollment ids | `SharedPreferences` | `biometric_sign_in_store.dart`; cleared on delete account |
| Onboarding drafts, selected baby, invite token | `SharedPreferences` | `session_cleanup.dart`, onboarding coordinator |
| Repository caches | In-memory | `session_cleanup.dart` |

No `flutter_secure_storage` usage found. Android manifest: `android:allowBackup="false"` (`AndroidManifest.xml`).

---

## 3. Third-party processors and infrastructure

| Provider | Role | Data involved | Code / infra references |
|----------|------|---------------|-------------------------|
| **Google Firebase** | Auth, App Check, FCM, Crashlytics | Email, UID, tokens, crash data | Mobile `pubspec.yaml`; API Firebase Admin delete on account delete |
| **Google Cloud Platform** | Cloud Run (API, worker), Cloud SQL, GCS, Pub/Sub, Secret Manager | All backend-stored data; logs | `infra/terraform/`; worker `main.py` |
| **Mailjet** | Transactional invite email | Invitee email, invite link, inviter copy | `invite_email.py` |
| **Google Sign-In** | OAuth for Firebase | Email/profile per Google account settings | `auth_repository.dart` |

**Owner/lawyer review:** Subprocessor list, DPA/SCCs, and region of Cloud SQL / GCS (`infra/terraform/modules/platform/sql.tf`, `storage.tf`).

---

## 4. Retention and lifecycle

| Mechanism | Behavior | References |
|-----------|----------|------------|
| Pending invitations | `expires_at`; worker marks `expired` when past due | `invite_cleanup.py`; `scripts/setup-schedulers.sh` (daily cron) |
| GCS bucket lifecycle | Abort incomplete multipart after 1 day; optional delete noncurrent versions after 30 days | `infra/terraform/modules/platform/storage.tf` |
| Export jobs stuck in `running` | Reclaimed to `pending` after 30 minutes | `baby_data_export.py` |
| Cloud SQL PITR | Log retention (e.g. 7 days prod) | `infra/terraform/environments/prod/main.tf` |
| Pub/Sub DLQ | Message retention (documented in ops) | `infra/gcp/SETUP.md` |
| Account / baby delete | **Soft delete** in Postgres; Firebase user **hard deleted** | `domain/account_delete.py`, `account_delete.py` |
| GCS on account/baby soft-delete | **Not bulk-deleted** by production API/worker | Per-photo delete exists (`storage.py`); `infra/db/hard_delete_user.py` is ops/dev tooling with optional GCS purge |
| Authored content after account delete | Comments, photos, suggestions **may remain** with anonymized/tombstone display rules | `active_participants.py` module docstring |
| Participation rows on delete | RSVPs, votes, likes, squishes **removed** | `purge_participation` in `active_participants.py` |

**Owner/lawyer review:** Define policy for orphaned GCS objects and tombstoned SQL rows; align with Play “account deletion” and regulatory erasure timelines.

---

## 5. User rights flows (implemented)

### 5.1 Account deletion

1. **Account** → delete account → `/account/delete` (`account_screen.dart`, `delete_account_screen.dart`).
2. Preview: `GET /v1/me/delete-account/preview` (sole-owned babies).
3. Confirm dialog; re-authenticate (password or Google if applicable).
4. `POST /v1/me/delete-account` with `{ "confirm": true }`.
5. Server: soft-delete SQL (revoke invites, soft-delete sole-owned babies, end memberships, purge participation, revoke biometric creds, tombstone user) then `firebase_auth.delete_user` (`domain/account_delete.py`).
6. Client: clear biometric enrollment, `SessionCleanup`, sign out, route to onboarding.

**Not in-app:** Bulk hard delete of all GCS media for deleted accounts (see §4).

### 5.2 Baby profile deletion (owner)

Separate flow: `delete_baby_profile_flow.dart` → `DELETE /v1/babies/{id}` (sole owner only). Co-owned babies require leaving instead (`members.py`).

### 5.3 Data export (baby archive)

1. **Account** → export baby data (owners only) → `/account/export` (`baby_data_export_screen.dart`).
2. `POST /v1/babies/{id}/data-export`; poll `GET .../data-export/latest`.
3. Worker builds JSON **export_version 2**, uploads to GCS `exports/{baby_id}/{job_id}/export.json`, signed download URL when `ready`.
4. Export **includes** baby-scoped tables in `COVERED_TABLES` (`export/coverage.py`).
5. Export **excludes** emails, Firebase UIDs, device tokens, per-user notification inbox (`EXCLUDED_TABLES`; scrubbing in `export/people.py`).

### 5.4 Profile edit and notification controls

`PATCH /v1/profile`; notification preference endpoints in `routers/profile.py` and `routers/notifications.py`.

### 5.5 Legal documents in app

Bundled WebView HTML (placeholders today): `assets/legal/terms.html`, `privacy.html`; routes `/legal/terms`, `/legal/privacy` (`legal_document_screen.dart`). **This deliverable adds publishable drafts** under `docs/legal/` and static hosting copies under `hosting/public/legal/`.

---

## 6. Security measures (factual, from code)

- HTTPS API calls with Firebase ID token; App Check on API requests (mobile).
- Passwords handled by Firebase Auth (not stored in app database).
- Biometric sign-in: challenge/response; private key on device.
- Signed URLs for media upload/download; uniform bucket-level access on GCS buckets.
- Invite tokens stored as hashes in DB; plain token in email/link only.

---

## 7. Open questions for owner / legal counsel

1. Legal entity name, registered address, and `{{CONTACT_EMAIL}}` for privacy/data requests.
2. `{{EFFECTIVE_DATE}}`, governing law `{{JURISDICTION}}`, and whether EU/UK/CA users need separate clauses.
3. Baby/child data: lawful basis, parental consent, and COPPA/GDPR Art. 8 positioning (**Owner/lawyer review**).
4. Retention period for tombstoned `app_users` rows and soft-deleted `baby_profiles` / media in GCS.
5. Whether `email_digest_enabled` requires disclosure despite **no Mailjet digest sender** found in worker (only weekly **push** digest: `weekly_notification_digest` in worker `main.py`).
6. International data transfers and Google/Mailjet DPAs.
7. Age rating and Play “target audience” given family/child **content** created by adults.
8. Update in-app `assets/legal/*.html` to match published web policy (out of scope for this PR per “no app code” — track in launch checklist).

---

## 8. Document map

| Artifact | Path |
|----------|------|
| Privacy policy (draft) | `docs/legal/privacy-policy.md` |
| Terms of service (draft) | `docs/legal/terms-of-service.md` |
| Public HTML | `hosting/public/legal/` |
| Play listing | `docs/store/play-listing.md` |
| Launch checklist | `docs/store/launch-checklist.md` |
