# Development guide

## Repository layout

```
lanonna_app/
├── apps/
│   └── mobile/              # Flutter client (Firebase Auth, API client, display encode)
├── services/
│   ├── api/                 # Cloud Run HTTP API (JWT, CRUD, signed GCS URLs)
│   └── worker/              # Cloud Run Pub/Sub worker (thumbs, email, FCM)
├── scripts/                 # verify-dev-prerequisites.sh, infra smoke, Run IAM, ship APK
├── packages/
│   └── email-templates/     # Mailjet HTML/text templates (versioned)
├── hosting/                 # Firebase Hosting (invite landing, email-verified continue URL, App Links)
├── infra/
│   ├── db/                  # `apply_migrations.py`, `clear_dev_test_data.py`, migrations/
│   ├── terraform/           # GCP platform (dev/prod)
│   └── gcp/                 # Resource inventory (SETUP.md)
└── docs/                    # product/ + engineering/ documentation
```

**Deploy model:** `api` and `worker` ship as **two Cloud Run services** — see [platform-architecture.md](platform-architecture.md).

**Before main product work:** [operations.md](operations.md#dev-readiness-gate) and `./scripts/verify-dev-prerequisites.sh`.

### Mobile feature modules (`apps/mobile/lib/features/`)

| Module | Shell route | Notes |
|--------|-------------|--------|
| `home/` | `/home` | Owner expecting/born; `home-summary`; announce arrival |
| `gallery/` | `/gallery`, `/gallery/recent`, `/gallery/favorites` | Grid with comment/squish badges when count **> 0** (FR-GAL-012); **photo detail** uses initial load spinner only (`core/presentation/detail_screen_load.dart`); squish/comment/caption refresh in place (`_refreshPhotoDetail` / local patch); `/gallery/photo/:id`; calendar **event detail** same pattern; all-mode **Recent Activity** from `GET …/activity-events?scope=gallery` (squish/comment events; prototype row UI). **`GalleryRepository`** is a `ChangeNotifier` (like calendar); list uploads/mutations call **`notifyGalleryDataChanged`** so shell tabs + home teasers reload; FAB upload polls processing by **`photoId`** before refreshing thumbs. |
| `calendar/` | `/calendar` | Month grid; default body is **Today** + **Upcoming**; day tap selects a date and shows that day’s list (`CalendarSelectedDaySection`); **Show all** / month change clears selection; event CRUD; static AI suggestions (`AiSuggestionsScaffold` + asset) |
| `registry/` | `/registry` | Needed/purchased, shipping, purchase claim; AI suggestions |
| `baby/` | (shared) | `CreateBabyScreen` + submit helper — onboarding and `/baby/create` modes |
| `account/` | `/profile`, `/account/edit`, `/baby/create`, `/baby/:id/edit`, `/baby/:id/followers` | Profile card, baby list, add/edit baby; **`/baby/create`** uses shared [`CreateBabyScreen`](../../apps/mobile/lib/features/baby/presentation/create_baby_screen.dart) (`CreateBabyMode.inApp`) — same prototype create-baby UX as onboarding, without first-moment/invite |
| `announcement/` | `/baby/:id/announcement`, `/baby/:id/announcement/create` | Keepsake card (signed `photo_display_url` on GET) + create |
| `shell/` | (sheet from tab `HomeTopBar`) | Baby switcher; **My Account** footer |
| `onboarding/`, `invitations/` | Onboarding + deep links | Owner/follower/co-owner paths; owner create-baby route wraps shared `CreateBabyScreen` (`CreateBabyMode.onboarding`) |
| `fun/` | `/gamification` (shell tab) | Names, gender/birthdate predictions |
| `search/` | `/search` | Global baby-scoped search |
| `settings/` | `/settings` | App settings; biometric unlock toggle (server flag via `PATCH /v1/profile`) |
| `legal/` | `/legal/terms`, `/legal/privacy` | Static legal copy |
| `home/` (activity) | `/home/activity` | Full home activity feed |
| `account/` (inbox) | `/notifications/inbox` | Notification inbox |

Repositories are registered in `bootstrap.dart`; routes in `core/router/app_router.dart`. Legacy redirects: `/login` → onboarding login, `/role-selection` → owner carousel. Shared API models (e.g. `BabySummary`) live under `apps/mobile/lib/core/domain/`. **Selected baby:** `HomeRepository.resolveSelectedBaby(SelectedBabyStore)` — use for baby-scoped loads (not raw `selectedBabyId` alone). After a successful `/v1/babies` fetch, the repo keeps an in-memory list for offline resolution; tab screens use `BabyContextReload` (`HomeRefreshSignal.babyContext`, reconnect) and stale-while-revalidate loads via `TabLoadGenerationCache`; **Home** also listens to `HomeRefreshSignal.homeTab` (nav re-tap, cross-tab teasers). `notifyBabyContextChanged` is the single reload signal for baby switch (not `SelectedBabyStore` listeners). `AsyncTabBody` for load errors. **Route-scoped baby:** `HomeRepository.babyById(id)` for deep links and screens keyed by `babyId` in the URL. Static catalogs: `assets/calendar/event_suggestions.json`, `assets/registry/registry_suggestions.json`.

### API layout (`services/api/src/lanonna_api/`)

| Layer | Role |
|-------|------|
| `routers/` | HTTP handlers (`photos`, `events`, `registry`, `fun`, `babies`, …) |
| `domain/` | Membership, permissions, activity + notify hooks (`gallery`, `calendar`, `registry`, `fun`, `home`, `notifications`, `invitations`, **`member_lifecycle`**, `onboarding`, `membership`, `name_suggestions`, `url_validation`, **`users_display`**) |
| `repositories/` | Parameterized SQL only |

**Liveness:** `GET /health` is public (no JWT / App Check) — see route table below.

**CORS:** Mobile clients do not need CORS. For a future browser client, set API env `CORS_ALLOW_ORIGINS` to a comma-separated allowlist (empty = middleware off).

**Member display names (#7):** Family-visible labels come from `app_users.display_name` only. Use [`domain/users_display.py`](../../services/api/src/lanonna_api/domain/users_display.py) (`author_display_name_from_row`, `uploader_display_name_from_row`, `purchaser_display_name_from_row`, `rsvp_display_name_from_row`) — never derive labels from email. SQL should alias `u.display_name` as the matching `*_display_name` (RSVP rows use unaliased `display_name` read by `rsvp_display_name_from_row`). Empty/null → **Family member**; activity/notification actor without profile → **Someone** (`actor_display_name`).

| `storage.py` | V4 signed PUT (upload) and GET (thumb/display read) |

## Prerequisites

- Flutter SDK (see `apps/mobile`)
- GCP `lanonna-dev` on Blaze, `us-central1` — [operations.md](operations.md)
- Docker optional (deploy uses Cloud Build)

## Mobile app

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json

Release and profile builds must pass a non-empty `API_BASE_URL` (see `flavors/*.json`). `AppConfig` reads it with const `String.fromEnvironment`, which honors `--dart-define-from-file=flavors/dev.json`. A missing or empty value fails compilation with `Release builds must set API_BASE_URL via --dart-define-from-file=flavors/dev.json` (L-07). The failure is a const integer-division error, not an `assert`: release and profile compilation strips asserts, which would otherwise fall through to the baked-in dev URL. Debug builds without the define use that dev URL. Do not gate this with a non-const `bool.hasEnvironment` check: AOT release builds report that as false and used to throw on the splash screen.
```

`google-services.json` / `GoogleService-Info.plist` are local (gitignored). Dev flavor: `apps/mobile/flavors/dev.json`. iOS: minimum **15.0**, run `cd ios && pod install` once.

**Android release:** `release` builds enable R8 + resource shrinking (`android/app/build.gradle.kts`, `proguard-rules.pro`). Smoke with `flutter build apk --release --dart-define-from-file=flavors/dev.json` after Gradle changes.

**Android orientation:** the main activity sets `android:screenOrientation="portrait"`, and `main()` calls `SystemChrome.setPreferredOrientations` with `portraitUp` on Android only. iOS orientations are unchanged.

**UI conventions:** Use [`AppColors`](../../apps/mobile/lib/core/theme/app_colors.dart) in feature code (no raw `Color(0x…)`). User-visible copy belongs in [`app_en.arb`](../../apps/mobile/lib/l10n/app_en.arb). API mutations from screens should use [`runMutation`](../../apps/mobile/lib/core/api/run_mutation.dart) unless validation errors stay inline on the form.

### Text input capitalization

User-facing text fields should use [`AppTextField`](../../apps/mobile/lib/core/widgets/app_text_field.dart) (or [`OnboardingTextField`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_fields.dart) with `AppTextInputKind`) instead of raw `TextField` + `TextCapitalization`. Policy lives in [`app_text_input_kind.dart`](../../apps/mobile/lib/core/input/app_text_input_kind.dart): `personName` (capitalize the first letter of each word or hyphen/apostrophe-separated part; preserve internal capitals such as McKenzie or `QAOwnerName`), `prose` (sentence-case), `none` (email, password, URLs, search). On submit, call `AppTextInputPolicy.normalizeForSubmit(kind, text)` before persisting to the API. Registry shipping street, apt, and city use `personName`; state/province uses the same while typing and [`formatRegistryShippingRegion`](../../apps/mobile/lib/features/registry/domain/registry_shipping_input.dart) on save (uppercase 1–3 letter all-alpha codes). Fun name dedup on the API is case-insensitive per baby and gender.

Transient feedback uses [`AppSnackBar`](../../apps/mobile/lib/core/widgets/app_snackbar.dart): `showInfo` (1s acknowledgments) and `showAlert` (4s validation/errors). Do not call `ScaffoldMessenger.showSnackBar` directly.

### Automated tests

| Layer | Command | Notes |
|-------|---------|--------|
| Mobile unit/widget | `cd apps/mobile && flutter test` | Part of `verify-dev-prerequisites.sh` |
| Mobile chip policy | `cd apps/mobile && bash scripts/check-no-material-chips.sh` | Fails on Material `Chip` / `FilterChip` in `lib/`; runs in `verify-dev-prerequisites.sh` |
| Mobile integration | `flutter test integration_test/home_summary_load_test.dart` (device/emulator) | Run locally before release |
| Maestro (Android) | `./maestro/scripts/run-maestro-smoke.sh` after proxy + deploy | See [maestro/README.md](../../apps/mobile/maestro/README.md) |
| API | `PYTHONPATH=services/api/src services/api/.venv/bin/pytest -q services/api/tests` | Run when touching API; included in `verify-dev-prerequisites.sh` compile path — run pytest explicitly for API changes |
| Worker | `cd services/worker && PYTHONPATH=src ../api/.venv/bin/python -m pytest -q tests` | Reuses the API venv (it has the worker's test deps); run when touching the worker |

Run **all three suites** before shipping — there is no CI, so they are the only automated gate. Flutter widgets that render the shell top bar (home, gallery, calendar tabs) need `ConnectivityService.forTesting()` and `FakeNotificationsRepository` (`apps/mobile/test/support/`) in the test `MultiProvider`. API repository SQL is mocked in most tests. `services/api/tests/integration/` (pytest marker `integration`) runs search, user provisioning, and the owner-onboarding gate against local Postgres: the fixture applies `infra/db/migrations/` to database `lanonna_pytest` on `127.0.0.1:5432` as user `postgres` / password `postgres`. Start PostgreSQL before `pytest`. Column-conformance unit tests such as `services/api/tests/test_search_repository.py` still lock SQL text. Search `ILIKE` uses a one-character backslash escape: the Python string must be `ESCAPE '\\'`. `ESCAPE '\'` compiles to an empty escape, so `%` and `_` stay wildcards (#3).

**Signed read URLs** expire after **900s** ([`storage.py`](../../services/api/src/lanonna_api/storage.py)). `CachedSignedImage` accepts optional `onSignedUrlError` (one callback per widget mount) so parents can refresh API data (home teasers, photo detail).

### Maestro E2E (Android)

Black-box UI tests under `apps/mobile/maestro/`. Use semantics ids (`nav_home`, `auth_sign_in`, …) via `AppSemantics` in `lib/core/widgets/app_semantics.dart`. Copy `maestro/local.env.example` → `maestro/local.env` with the dev smoke password (`lanonna.dev.smoke@test.com`). Start Cloud SQL Auth Proxy (port **5433** recommended when **5432** is in use; set `DB_PORT` consistently). Scripts:

| Script | Scope |
|--------|--------|
| `./maestro/scripts/run-maestro.sh` | **Smoke** (default): provision smoke user, build/install, App Check prep, four `flows/smoke/*` flows |
| `./maestro/scripts/run-maestro-smoke.sh` | Same as above (explicit) |
| `./maestro/scripts/run-maestro-full.sh` | Smoke + feature + follower + invite deep link + fresh onboarding (final gate) |

See [maestro/README.md](../../apps/mobile/maestro/README.md).

### Theming (single source of truth)

Product UI tokens live under `apps/mobile/lib/core/theme/` (see also PRD §5.1):

| File | Role |
|------|------|
| `app_colors.dart` | Raw brand hex (palette only) |
| `app_metrics.dart` | Spacing, radii, button sizes, `choicePill*`, `appChip*` |
| `app_text_theme.dart` | Inter + Baloo 2 text styles; tab screen titles use `headlineSmall` (Baloo 2, 24px) |
| `app_brand_theme.dart` | `ThemeExtension` — sage/peach tints, insight fills |
| `app_theme.dart` | `AppTheme.light` → `ThemeData` + component themes |
| `la_nonna_theme.dart` | `context.textStyles`, `context.brand`, `context.colors` |
| `theme.dart` | Barrel export for feature imports |

`MaterialApp` uses `theme: AppTheme.light` in `main.dart`. **New screens:** import `core/theme/theme.dart`, use `context.textStyles`, `context.brand`, `context.colors`, and `AppMetrics` — do not add inline `GoogleFonts` or one-off hex in features. Shared widgets (`OnboardingHeadline`, `OnboardingPrimaryButton`, home shell) already use this layer.

**Shell vs subpage chrome (FR-SHELL-001):** Bottom-tab screens wrap content in `ShellTabLayout` (home top bar: baby switcher, search, notifications). Drill-downs, settings/account stack routes, and forms such as calendar/registry edit use `PrototypeSubpageScaffold` (back + centered title only). Do not stack `shellHomeTopBar` on subpages. Icon-only controls use [`AppIconButton`](../../apps/mobile/lib/core/widgets/app_icon_button.dart), which requires a label (tooltip + semantics) and hides the icon glyph from the screen reader. Subpage Back, calendar month arrows, home photo thumbnails (`Open photo`), and tappable activity rows (the activity summary) follow that pattern (#49).

**Home scroll sections:** Build blocks with [`HomeScrollSection`](../../apps/mobile/lib/features/home/presentation/widgets/home_scroll_section.dart) (header + body + `sectionBlockSpacing`). Trailing controls: [`HomeSectionLink`](../../apps/mobile/lib/features/home/presentation/widgets/home_section_trailing.dart) / `HomeSectionMeta` only — not raw `TextButton` on section headers. Bordered bodies: `HomeScrollSection.bordered` → `AppBorderedSurface` + `AppMetrics.surfacePadding` (or `padding: EdgeInsets.zero` for `ListTile` lists). Low-level [`HomeSectionHeader`](../../apps/mobile/lib/features/home/presentation/widgets/home_section_header.dart) uses fixed `sectionHeaderRowHeight` + `sectionTitleGap`.

**Bordered tiles (#410):** Apply horizontal inset once — `AppMetrics.horizontalPadding` on home sections (or pass it via `AppBorderedSurface` `margin`), and `AppMetrics.subpageScrollPadding` on stack subpage `ListView`s. Use [`AppBorderedSurface`](../../apps/mobile/lib/core/widgets/app_bordered_surface.dart) for bordered profile/settings/home tiles instead of `Card` when you need home-aligned width. `CardTheme` keeps vertical spacing only (no horizontal margin).

**Section titles:** Block headers on subpage/tab scrolls use [`AppSectionTitle`](../../apps/mobile/lib/core/widgets/app_section_title.dart) (built-in `AppMetrics.sectionTitleGap`, 10px). Home tab blocks use [`HomeSectionHeader`](../../apps/mobile/lib/features/home/presentation/widgets/home_section_header.dart) (same gap token). Separate major sections with `AppMetrics.sectionBlockSpacing` (16). Form field labels use `OnboardingFieldLabel` / `AppLabeledTextField`, not `AppSectionTitle`.

**Text fields:** Typed input uses `AppTextTheme.fieldInput` (Inter **regular**, w400). Use [`AppTextField`](../../apps/mobile/lib/core/widgets/app_text_field.dart), [`AppLabeledTextField`](../../apps/mobile/lib/core/widgets/app_labeled_text_field.dart), or [`AppTextFormField`](../../apps/mobile/lib/core/widgets/app_text_form_field.dart) — not raw `TextField` / `TextFormField` (theme `bodyLarge` is bold).

**Localization (FR-SET-002):** User-visible strings belong in [`app_en.arb`](../../apps/mobile/lib/l10n/app_en.arb); run `flutter gen-l10n` after edits. Use ICU `{count, plural, …}` for quantity labels (photo squish/comment counts, prediction votes, name loves, registry teaser — #11); read via `AppLocalizations.of(context)!`. Do not hand-roll `'$n votes'` in widgets. Uppercase gender totals stay in [`VoteCountPill`](../../apps/mobile/lib/core/widgets/vote_count_pill.dart) (`1 VOTE` / `N VOTES`). RSVP status labels and event-detail “View RSVPs” teaser: [`rsvp_status_labels.dart`](../../apps/mobile/lib/features/calendar/domain/rsvp_status_labels.dart) (`rsvpSummaryViewAllTeaser` — #18). Event and photo comments share [`CommentComposerController`](../../apps/mobile/lib/core/comments/comment_composer_controller.dart) and [`pushAndRefresh`](../../apps/mobile/lib/core/presentation/detail_screen_load.dart), which unfocus the composer before a sub-route and again after every pop so returning from Edit does not open the keyboard (#17, #35). Gender vote empty state: [`gender_vote_display.dart`](../../apps/mobile/lib/features/fun/domain/gender_vote_display.dart) (#22).

**API errors from UI mutations (#8):** Repository calls throw [`ApiException`](../../apps/mobile/lib/core/api/api_exception.dart); map with [`apiErrorMessage`](../../apps/mobile/lib/core/api/api_error_message.dart). Use [`runMutation`](../../apps/mobile/lib/core/api/run_mutation.dart) in presentation for create/update/delete actions so users always see server `detail` (e.g. Fun name limit). **Client-side** required fields: `Form` + [`form_validators.dart`](../../apps/mobile/lib/core/validation/form_validators.dart) + `AppLabeledTextFormField` (registry item, shipping address); lightweight `Form` on Fun name suggest card. Do not silently `return` on empty required input or show raw `'Save failed: $e'`. **Post-submit revalidation (FR-SET-002 / #21):** on failed `validate()`, set `_validateOnInteraction = true` and pass `AutovalidateMode.onUserInteraction` to the `Form` and each field (`OnboardingTextField`, `OnboardingTermsFormField`, `OnboardingRelationshipFormField`, registry `AppLabeledTextFormField`). Keep screen-level `_error` for API/auth failures only.

**Onboarding sign-in UI:** Google OAuth uses the multicolor mark in [`assets/branding/google_sign_in_g.svg`](../../apps/mobile/assets/branding/google_sign_in_g.svg) via [`GoogleLogoMark`](../../apps/mobile/lib/core/widgets/google_logo_mark.dart) on [`OnboardingGoogleButton`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_buttons.dart) (login + signup). Facebook login is **not implemented** (prototype only); deferred plan: [facebook-login-implementation-plan.md](facebook-login-implementation-plan.md). Owner/follower welcome carousels use [`OnboardingCarousel`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_carousel.dart) (prototype layout: [`Expanded`](https://api.flutter.dev/flutter/widgets/Expanded-class.html) art region, [`OnboardingCarouselCaption`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_carousel_caption.dart) band, footer dots + primary **Next**). Email/password verify screen copy is ARB-only (no “Google skips verification” note — Google auth never lands on that screen).

**Onboarding choice controls:** [`OnboardingSegmentedControl`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_fields.dart) — full-width binary **track** with a sliding thumb; one side is always active (e.g. Expecting / Already born). [`OnboardingPillSelect`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_fields.dart) — optional pills (`selectedIndex` may be null). Use `OnboardingPillLayout.wrap` for multi-option fields that may wrap (create-baby gender). Use `OnboardingPillLayout.equalWidthRow` for optional binary fields that should span the form width (owner complete profile Mother / Father). Metrics: `AppMetrics.choicePill*`.

**Avatar / profile photo pickers:** [`PrototypePhotoUpload`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart) (circle) + grey tappable [`OnboardingPhotoCaption`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart) (`Add a photo` / `Change photo`); same `onTap` on both.

**App chips (no Material `Chip` / `FilterChip`):** Use [`app_chip.dart`](../../apps/mobile/lib/core/widgets/app_chip.dart) — `AppToggleChip` (RSVP, tabs, presets, tags), `AppRemovableChip` (sage boy / peach girl name drafts), `AppBadgeChip` (role, counts). Accents: `AppChipAccent.sage`, `peach`, `neutral`. Metrics: `AppMetrics.appChip*`. Guard: `cd apps/mobile && bash scripts/check-no-material-chips.sh` (also runs in `verify-dev-prerequisites.sh`).

**Auth (FR-AUTH-007):** Password reset uses Firebase `sendPasswordResetEmail` via [`AuthRepository.sendPasswordResetEmail`](../../apps/mobile/lib/core/auth/auth_repository.dart). Login **Forgot password?** pre-fills the email field when valid; otherwise [`showForgotPasswordEmailDialog`](../../apps/mobile/lib/features/onboarding/presentation/widgets/forgot_password_dialog.dart). Incoming reset links are handled like other Firebase auth actions in [`auth_action_app_link.dart`](../../apps/mobile/lib/core/deep_links/auth_action_app_link.dart). **Firebase Auth errors (#40):** On sign-in, sign-up, password reset, and Google OAuth, map `FirebaseAuthException` with [`authErrorMessage`](../../apps/mobile/lib/core/auth/auth_error_message.dart) and `AppLocalizations` — never show `e.message` or `e.code`. Email verification resend / link apply keep copy in [`auth_email_verification.dart`](../../apps/mobile/lib/core/auth/auth_email_verification.dart).

**Member lifecycle (FR-INV-009 / FR-INV-010 / #25):** Onboarding status and `GET /v1/babies` report only active memberships (`removed_at IS NULL`). A signed-in user with no active memberships looks the same as someone who has not created or joined a baby, so routing still resumes owner create-baby. `has_removed_membership` is a per-baby server check and is not on `OnboardingStatusResponse`. Remove and leave in [`member_lifecycle.py`](../../services/api/src/lanonna_api/domain/member_lifecycle.py); routes in [`routers/members.py`](../../services/api/src/lanonna_api/routers/members.py). Mobile: [`followers_screen.dart`](../../apps/mobile/lib/features/account/presentation/followers_screen.dart), leave in [`baby_switcher_sheet.dart`](../../apps/mobile/lib/features/shell/presentation/baby_switcher_sheet.dart). Re-invite reactivates the `baby_memberships` row on accept and does not restore RSVPs, votes, name loves, or squishes removed when the membership ended. Comments, photos, name suggestions, and registry claims stay. Counts and lists use [`active_participants.py`](../../services/api/src/lanonna_api/repositories/active_participants.py): a participant counts only with `removed_at IS NULL` and `app_users.deleted_at IS NULL`. Migration `033` deletes presence rows already left behind. Ended membership on baby-scoped routes: API `403` with `detail.error == membership_ended` from [`membership_access.py`](../../services/api/src/lanonna_api/domain/membership_access.py) (`require_active_membership` / `require_membership`, home, search); client refreshes selection via [`membership_access_handler.dart`](../../apps/mobile/lib/core/auth/membership_access_handler.dart) (`ApiClient.registerMembershipEndedHandler`).

**Invite accept policy (FR-INV-002 / #26):** Product rules live in [`services/api/src/lanonna_api/domain/invitations.py`](../../services/api/src/lanonna_api/domain/invitations.py) (preview `accepted`/`revoked`; accept checks membership before non-pending status). A preview with `status: accepted` still includes the baby payload. The invite landing screens treat that as “You're already a member” and show **Open** instead of Accept. Open sends a signed-out visitor to login. A signed-in visitor calls accept, which returns `already_member` when they still belong to the baby. The preview endpoint is public and does not return a separate `already_member` flag. **Co-owner (`role=owner`) accepts** lock the baby row (`lock_baby_profile_for_update`) before counting active owners, so concurrent accepts cannot exceed the 2-owner cap (`409 max_owners`). Mobile treats `InvitationPreview.canContinueInviteFlow` (`pending` or `accepted`) as routable — not “expired”.

**Invite flow privacy (M-54):** Do not put invitee/signed-in emails or invite tokens in internal GoRouter query strings. Use in-memory [`InviteFlowState`](../../apps/mobile/lib/features/invitations/presentation/invite_flow_state.dart) for email-mismatch UI, login/signup prefill, and invite resume after switch-account. External deep links may still use `/invite-accept?token=…`. Persisted invite preview JSON omits `invitee_email`; `pending_invite_token` stays in `SharedPreferences` until sign-out. Android: `allowBackup=false` in `AndroidManifest.xml`. A warm invite link is applied after the current frame (`LaNonnaApp`), and the router redirect receives the full URI so the query token survives. The create-baby onboarding screen writes the create-baby step only while that route is still current, so an invite opened there reaches the same preview as a cold start. `redirectFor` already allows `/invite-accept` for a signed-in user who has finished their profile and has no baby.

**Deleted account sessions (#30 / NFR-DATA-001) and provisioning (#36 / #37):** [`current_user`](../../services/api/src/lanonna_api/auth.py) verifies the Firebase ID token and does not read or write `app_users`. Every other authenticated route depends on [`current_app_user`](../../services/api/src/lanonna_api/auth.py), which calls [`resolve_app_user`](../../services/api/src/lanonna_api/repositories/users.py) once per request. Tombstoned `app_users` → **401** `detail.error = user_deleted`, and the row is not rewritten. `POST /v1/me/delete-account` stays on `current_user` so a retry can finish Firebase deletion after the SQL tombstone. The delete screen confirms in a second dialog that lists `sole_owned_babies` from eligibility, and password or Google sessions reauthenticate before that call (#60). `resolve_app_user` keeps a stored email when the token omits one (`COALESCE`), moves `updated_at` only when the email changes, and throttles `last_seen_at` to 15 minutes (migration `030`). Emails already stored as null are backfilled with [`infra/db/backfill_null_user_emails.py`](../../infra/db/backfill_null_user_emails.py) (dry-run by default; `--apply` writes only where Firebase still has an email; `--report-orphans` is read-only). Pending invites addressed to a deleted account's former email are not auto-revoked. Participation on babies that remain (RSVPs, gender and birthdate votes, name loves, photo and announcement squishes) is removed on delete (migration `032` cleans rows already left behind) and is excluded from counts and lists by the same active-participant rule (current membership and account not deleted). Comments, photos, and name suggestions stay, labeled with the anonymized display name, and comment counts still include those comments. Registry claims stay so a purchased item is not listed as available again. Mobile [`ApiClient`](../../apps/mobile/lib/core/api/api_client.dart) invokes [`handleUserDeletedSession`](../../apps/mobile/lib/core/auth/user_deleted_session_handler.dart) (sign out + login route).

**Birth announcement API (#23 / #34):** Validation in [`domain/announcement_validation.py`](../../services/api/src/lanonna_api/domain/announcement_validation.py) (birth date via `validate_actual_birth_date`, `HH:MM` birth time, gender enum; name/measurement text length caps). Partial updates: **`PATCH /v1/babies/{id}/announcement`** with `exclude_unset` merges into existing row in [`patch_announcement`](../../services/api/src/lanonna_api/domain/announcement.py). Mobile saves via `patchJson`.

**Biometric unlock (PRD §5.3 / M-31):** Optional `biometric_unlock_enabled` on profile. Mobile [`BiometricAppLock`](../../apps/mobile/lib/core/auth/biometric_app_lock.dart) prompts device biometrics on cold start / resume when Firebase session exists and onboarding is complete; toggle in Settings requires a successful local auth before enabling. Not a login replacement.

**Profile PATCH (#32 / #38):** `PATCH /v1/profile` uses `exclude_unset` + [`patch_profile_fields`](../../services/api/src/lanonna_api/repositories/users.py); omitted fields are not nulled; account edit uses explicit `null` to clear. User `birth_date` is validated in [`domain/date_validation.py`](../../services/api/src/lanonna_api/domain/date_validation.py) (`validate_user_birth_date`: not after UTC today + 1-day slack, not before `1900-01-01`). Optional `phone` is normalized in [`domain/phone.py`](../../services/api/src/lanonna_api/domain/phone.py) (digits, spaces, `+ - ( )`, 7–20 digits, leading `+` kept); anything else is 422. `display_name` is trimmed and must still be at least 1 character. Edit Profile uses the same `Form` validators as complete-profile (`validateOnboardingFirstName`, `validateOnboardingLastName`, `validateOptionalPhone`) and does not substitute the name "Account". A successful save updates [`AccountRepository.profileUpdates`](../../apps/mobile/lib/features/account/data/account_repository.dart) and notifies listeners so My Account shows the new name without leaving the screen (#58). The shell title stays the selected baby name. Baby/announcement dates share [`validate_actual_birth_date`](../../services/api/src/lanonna_api/domain/date_validation.py). Mobile DOB pickers: `firstDate: 1900`, `lastDate: today` on account edit and onboarding complete profile. **`/v1/onboarding/status` (#31):** Owner onboarding is gated on an active owner membership with `baby_memberships.joined_via = 'created'`, not on `baby_profiles.created_by_firebase_uid` and not on any owner role. Creating a baby inserts `joined_via = 'created'`. Accepting an invite inserts `joined_via = 'invite'`. Reactivation keeps the original value. Migration `031` backfills existing rows to `invite`, then marks the earliest owner membership (including removed rows) as `created`, and repairs `created_by_firebase_uid` to that earliest owner when it differs. `needs_owner_onboarding` = not `owner_onboarding_completed` and the user has a self-created baby. `owner_onboarding_baby_profile_id` = newest self-created owner baby (`ORDER BY baby_profiles.created_at DESC`), or `null` when none. `has_owner_baby` is still any active owner role, including an invited co-owner, and does not by itself force onboarding. `can_access_main_app` = `profile_complete && (owner_onboarding_completed || has_follower_membership || (has_owner_baby && !has_self_created_baby))`. A follower who also created a baby and has not finished owner onboarding has `needs_owner_onboarding` true and `can_access_main_app` true. Mobile `AppSession.canAccessMainApp` and `redirectFor` use those server flags only; a device-local “onboarding completed” bit does not admit the main app or skip owner onboarding. A failed status fetch is `OnboardingStatusPhase.unavailable`, not an incomplete profile (#48): routing uses the last cached server status for that uid when one exists, otherwise `/session-offline` (shared offline copy + Try again). `AppSession.bindConnectivity` refreshes when the device comes back online while status is unavailable or stale. When both flags are true, Home stays reachable and owner onboarding routes stay reachable. When only `can_access_main_app` is true, onboarding routes redirect to Home. When only `needs_owner_onboarding` is true, `/home` resumes first-moment or batch-invite. `AppSession.refreshFromApi` copies `owner_onboarding_baby_profile_id` into local `owner_onboarding_baby_id` (`OnboardingCoordinator.createdBabyId`). Owner first-moment and onboarding batch-invite resolve the baby via [`OwnerOnboardingBabyResolver`](../../apps/mobile/lib/features/onboarding/domain/owner_onboarding_baby_resolver.dart) (local cache → status → one status refresh). Signed-in invite accept selects the joined baby via `rememberJoinedBaby` (accept result, then invited id, then cached preview) so an in-flight baby list cannot restore the previously selected profile.

**Onboarding profile Form:** [`OnboardingTermsFormField`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_fields.dart) and [`OnboardingRelationshipFormField`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_fields.dart) defer parent-driven `FormField.didChange` to the next frame so draft/server hydration does not call `markNeedsBuild` on an ancestor `Form` during build. [`RouterRefreshListenable`](../../apps/mobile/lib/core/router/router_refresh.dart) coalesces coordinator/session/auth notifications to post-frame so GoRouter redirects do not run mid-build.

**Offline / tab errors (NFR-OFFLINE-001 / #27):** [`api_error_message.dart`](../../apps/mobile/lib/core/api/api_error_message.dart) maps socket/client failures to short copy. Home, Calendar, Gallery, Registry, and Fun share [`resolveTabLoadKind`](../../apps/mobile/lib/core/presentation/tab_load_kind.dart): a spinner only when nothing is cached, then an error with Try again, then a true empty state. A failed refresh keeps the cached baby on screen and reports the failure with a snackbar. [`ApiClient`](../../apps/mobile/lib/core/api/api_client.dart) fails immediately when `ConnectivityService` is offline and applies `apiRequestTimeout` to the ID token and the HTTP call, so a hung socket becomes `network_timeout` instead of an infinite spinner (#27). The shell title reads `SelectedBabyStore.selectedBabyName`, the last name resolved from the server, when the baby list cannot be fetched. [`BabyContextReload`](../../apps/mobile/lib/features/home/presentation/baby_context_reload.dart) reloads those tabs when connectivity returns. [`AsyncTabBody`](../../apps/mobile/lib/core/widgets/async_tab_body.dart) is the error/retry body. [`OfflineBanner`](../../apps/mobile/lib/core/widgets/offline_banner.dart) uses top `SafeArea`. Global search uses the same error body and debounces keystrokes (#3). Photo caption edit requests focus when the edit icon is tapped and calls `dismissTextInputFocus` on save, the same keyboard dismissal as the shared comment composer (#35). Icon-only actions (event edit/delete, keepsake share/edit, photo delete and caption edit, per-comment edit/delete, gallery thumbnails, add photo) go through `AppIconButton` or `AppSemantics` with a label. Announce Arrival uses `Form` + `validateOnboardingFirstName`, so an empty first name shows “First name is required”.

**Event times (UTC-in / local-out, #4):** API `starts_at` / `ends_at` are UTC instants. Calendar **Today** lists every event whose **local start date** is today (including starts earlier the same day); data comes from the **current** `month=YYYY-MM` list. **Upcoming** uses `GET …/events?upcoming=true` (`starts_at >= now`) and drops rows already shown under Today — see [`partitionCalendarListEvents`](../../apps/mobile/lib/features/calendar/domain/calendar_event_lists.dart). Home teasers still use home-summary `upcoming_events` only. Create and update reject an `ends_at` earlier than `starts_at` with **400** via [`validate_event_time_range`](../../services/api/src/lanonna_api/domain/date_validation.py). A missing or explicit null `ends_at` is an open-ended event. An end equal to the start is allowed. Naive datetimes are treated as UTC. Parse with [`parseApiInstant`](../../apps/mobile/lib/core/time/app_date_time.dart) at model boundaries (`CalendarEvent`, home `NextUpEvent`, search hits). Submit with `toApiInstant`. Display via `formatEventListDateTime`, `formatEventDetailWhen`, and home badge helpers — do not format raw `DateTime` fields in widgets. Announcement birth time stays `HH:MM` on the API and is shown with `formatApiClockTime` (`DateFormat.jm`, so `15:30` is `3:30 PM` in en-US). Calendar month/day math uses `eventLocalStart` / `eventOnLocalCalendarDay` (re-exported from `calendar_display.dart`). **Date-only API strings** (`expected_birth_date`, birthdate guesses, invite preview, profile DOB, announcement birth date): parse with `tryParseApiCalendarDate`; display with `formatApiCalendarDate` / `formatApiCalendarDateFromParts` and `localeNameForFormatting(context)`; submit with `toApiCalendarDate` (#19). Use [`PrototypeDateField`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart) for date tiles (event form, create baby) — never hand-format `YYYY-MM-DD` in widgets.

### Reset dev test data (babies + onboarding)

Cloud SQL Auth Proxy + `DB_PASSWORD` (see [migrations/README.md](../../infra/db/migrations/README.md)):

```bash
cd infra/db
DB_PASSWORD="$PGPASSWORD" DB_PORT=5433 python clear_dev_test_data.py \\
  --email your@email.com --reset-onboarding
```

Clears babies and related rows for that user and clears `owner_onboarding_completed_at` so you can run owner onboarding again. Use `--dry-run` first; `--verbose` lists GCS `display/` paths (objects are not deleted from GCS).

### Helper scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `verify-dev-prerequisites.sh`, `verify-dev-migrations.sh`, `apply-dev-run-iam.sh`, `infra-smoke-display-upload.sh`, `run-beta-gate.sh` | Dev readiness, schema gate, worker Run IAM, upload smoke, beta gate — see [operations.md](operations.md) |
| `ship_release_apk_to_drive.sh`, `ship_release_apk_x86_64_to_drive.sh`, `copy_release_apk_to_drive.sh` | Build the release APK (universal / x86_64 emulator) and copy it to Drive; the copy script takes an optional destination file name |
| `setup-weekly-digest-scheduler.sh`, `setup-expired-invites-scheduler.sh` | Create the Cloud Scheduler jobs (weekly digest, expired-invite cleanup) |
| `sync-email-templates.sh`, `sync-firebase-auth-templates.sh`, `configure-firebase-auth-email-project.sh`, `deploy-invite-hosting.sh` | Mailjet template mirror check/apply; Firebase auth email templates (`check` / `check-remote` / `apply`) and public-facing name; HTTPS invite landing on Firebase Hosting |
| `hard_delete_user.sh <email>` | Hard-delete a dev user (SQL + GCS + Firebase); use `--dry-run` first |
| `provision_qa_validation_accounts.sh`, `seed_qa_gallery_photo.sh` | Provision QA owner/follower accounts and seed a gallery photo for Maestro/manual QA |
| `mark_firebase_email_verified.py <email>` | Mark a dev Firebase user email-verified when the inbox cannot receive mail (`@test.com`) |
| `configure-android-google-sign-in.sh` | One-time dev setup: Android debug SHA + refresh `google-services.json` for Google Sign-In |

## API rate limiting

Sensitive routes (`POST /v1/photos/init`, `POST …/invitations/batch`) use an **in-process** per-IP sliding window in `middleware/rate_limit.py` (30 requests / 60s per path per instance). Cloud Run scales horizontally, so the **effective** cap is roughly `30 × instance count` until you add a shared limiter (e.g. Cloud Armor, Redis/Memorystore) at the edge. No shared limiter is deployed in v1; document and monitor before wide public beta.

## Firebase JWT audiences

API verifies Firebase ID tokens with `firebase_admin.auth.verify_id_token`, then checks the token `aud` claim against `Settings.firebase_audience_allowlist()` (`GCP_PROJECT_ID` when `FIREBASE_AUDIENCES` is unset). Sideloaded dev APKs and emulators using the same Firebase project are unaffected. Misconfigured `FIREBASE_AUDIENCES` causes 401 for all real clients.

## API and worker

| Service | Cloud Run name | Deploy |
|--------|----------------|--------|
| API | `api` | `services/api/scripts/deploy.sh` |
| Worker | `worker` | `services/worker/scripts/deploy.sh` then `./scripts/apply-dev-run-iam.sh` |

Cloud Build / local Docker use repo-root [`.gcloudignore`](../../.gcloudignore) and [`.dockerignore`](../../.dockerignore) so uploads include only `packages/` and `services/` ([operations.md](operations.md)).

Dev API base URL: `apps/mobile/flavors/dev.json` → `API_BASE_URL` (sync steps: [flavors/README.md](../../apps/mobile/flavors/README.md); `gcloud run services describe api --region=us-central1 --format='value(status.url)'`)

| Method | Path | Auth |
|--------|------|------|
| GET | `/health` | Public liveness (`status`, `environment`) |
| GET | `/v1/app/version?platform=` | Public force-update config (`android` \| `ios`); `minimum_version`, `store_url` (migration `020_app_versions`; no JWT / App Check) |
| GET | `/v1/me/account` | Firebase Bearer JWT; profile + babies + `engagement` stats; `storage_usage` when user owns a baby. Auth smoke: unauthenticated request → 401. |
| GET, PATCH | `/v1/me/notification-preferences` | Digest (`realtime`/`daily`/`weekly`), push + email digest toggles; per-channel `notify_*_enabled` (`gallery`, `calendar`, `registry`, `comments`) |
| GET | `/v1/me/notifications` | In-app notification inbox |
| GET | `/v1/me/notifications/unread-count` | Unread inbox count (shell bell dot) |
| PATCH | `/v1/me/notifications/{id}/read` | Mark notification read |
| POST | `/v1/me/notifications/read-all` | Mark all inbox notifications read for the current user (`updated` count) |
| PUT, DELETE | `/v1/me/device-tokens` | Register or remove FCM device token (`platform`: `ios` \| `android`) |
| GET | `/v1/me/delete-account/eligibility` | Account deletion preflight (`allowed: true`, `blockers: []` in v1; `sole_owned_babies` is `{id, name}` for profiles delete will remove) |
| POST | `/v1/me/delete-account` | Soft-delete SQL first (sole-owned babies, memberships, `app_users.deleted_at`), then Firebase `delete_user` (#H-03). If Firebase fails after SQL, retry POST (skips SQL when already tombstoned). |
| GET | `/v1/babies/{baby_profile_id}/search?q=` | Cross-feature search (member) |
| POST | `/v1/babies/{baby_profile_id}/data-export` | Queue baby JSON export (owner); the worker runs it with Pub/Sub retry semantics ([worker README](../../services/worker/README.md)) |
| GET | `/v1/babies/{baby_profile_id}/data-export/latest` | Export job status (`pending` / `running` / `ready` / `failed`) + signed download URL |
| PATCH | `/v1/profile` | Firebase Bearer JWT; `display_name` (trimmed, min length 1), optional `avatar_url`, `phone` (normalized or 422), `birth_date`, `country_code`, `postal_code`, `accept_terms` (sets `terms_accepted_at`), `biometric_unlock_enabled` (optional bool). Read profile via `GET /v1/me/account`. |
| GET | `/v1/onboarding/status` | Firebase Bearer JWT |
| POST | `/v1/onboarding/owner/complete` | Firebase Bearer JWT |
| GET, POST | `/v1/babies` | Firebase Bearer JWT; create accepts optional `relationship_label`; **expecting** create may include `profile_name_suggestions` (`name` + `gender`) to seed Fun (#400) |
| PATCH | `/v1/babies/{baby_profile_id}` | Firebase Bearer JWT (owner); optional `avatar_url`; `lifecycle_status: born` records `baby_arrived` activity |
| GET | `/v1/babies/{baby_profile_id}/home-summary` | Firebase Bearer JWT (member); §6.2 blocks: `birth_welcome`, `system_announcements`, `teasers` (`recent_photos`, `upcoming_events` only), owner `new_followers` / `invite_status`, `recent_activity` teaser |
| GET | `/v1/babies/{baby_profile_id}/activity-events` | Paginated `activity_events` (`limit`, `offset`, optional `scope=gallery` for squish/comment only); items include `actor_display_name`, `photo_id` when applicable |
| POST | `/v1/me/system-announcements/{id}/dismiss` | Dismiss system banner |
| GET/POST/PATCH/DELETE | `/v1/admin/system-announcements` | Ops CRUD (`X-Admin-Key` header; Cloud Run secret `admin-api-key` → env `ADMIN_API_KEY`) |
| GET | `/v1/babies` | JWT; includes `can_leave` per membership (#25) |
| GET | `/v1/babies/{baby_profile_id}/members` | Firebase Bearer JWT (owner); members + `can_remove` |
| DELETE | `/v1/babies/{baby_profile_id}/members/{firebase_uid}` | Firebase Bearer JWT (owner); soft-remove member (#25) |
| POST | `/v1/babies/{baby_profile_id}/leave` | Firebase Bearer JWT (member); self leave (#25) |
| GET | `/v1/babies/{baby_profile_id}/invitations` | Firebase Bearer JWT (owner); pending invites |
| DELETE | `/v1/babies/{baby_profile_id}/invitations/{invitation_id}` | Firebase Bearer JWT (owner); revoke pending |
| GET, PUT | `/v1/babies/{baby_profile_id}/announcement` | JWT; birth announcement keepsake; GET includes `photo_display_url` when `photo_id` set |
| POST | `/v1/babies/{baby_profile_id}/announcement/squish` | JWT; toggle squish |
| POST | `/v1/babies/{baby_profile_id}/announcement/comments` | JWT; add comment |
| POST | `/v1/babies/{baby_profile_id}/onboarding/first-moment` | Firebase Bearer JWT (owner) |
| GET | `/v1/babies/{baby_profile_id}/membership-check?email=` | Firebase Bearer JWT (owner) |
| POST | `/v1/babies/{baby_profile_id}/invitations/batch` | Firebase Bearer JWT (owner); queues `send_invite_email` on Pub/Sub |
| GET | `/v1/invitations/preview?token=` | Public (invite deep link) |
| POST | `/v1/invitations/accept` | Firebase Bearer JWT + App Check; invitee email must match. Errors: **404** `not_found`, **410** `expired`, **403** `email_mismatch` (detail includes emails), **409** `max_owners` — JSON `detail.error` (mobile maps to `InvitationAcceptResult`) |
| POST | `/v1/uploads/display/signed-url` | JWT + App Check; avatar upload init: `content_type`, `byte_length` (≤ 2 MB), `scope` (`user` \| `baby`), optional `baby_profile_id` when `scope=baby`. Returns signed PUT + `object_path` under `avatars/`; persist path as `avatar_url`. Reads mint signed GET URLs on account/baby responses (900s TTL). Legacy `smoke/` paths still supported. |
| POST | `/v1/photos/init` | Firebase Bearer JWT (owner; gallery upload init); optional `caption` (max 2000) |
| GET | `/v1/babies/{id}/photos` | JWT (member); `limit`/`offset`; `sort=default\|recent\|favorites`; followers see `ready` only |
| GET, PATCH, DELETE | `/v1/babies/{id}/photos/{photo_id}` | JWT (member read; owner mutate); signed thumb/display URLs; GET includes `tagged_babies` |
| POST | `/v1/babies/{id}/photos/{photo_id}/squish` | JWT (member); toggle squish |
| POST, PATCH, DELETE | `/v1/babies/{id}/photos/{photo_id}/comments` | JWT (member); photo detail comments include `can_edit` / `can_delete` (`domain/content_permissions.py`: author edits; owner or author deletes) |
| PUT | `/v1/babies/{id}/photos/{photo_id}/tags` | JWT (owner); body `tagged_baby_profile_ids`. Photo detail `tagged_babies` and this response list only tags for babies the **viewer** belongs to (join `baby_memberships`; #9) |
| GET, POST | `/v1/babies/{id}/events` | JWT (member read; owner create); query `month=YYYY-MM`, `upcoming=true`. Optional `video_call_url`: `domain/url_validation.normalize_optional_http_url` (empty → null; bare domain → `https://`; http/https only). Mobile: `validateOptionalHttpUrl` / `normalizeOptionalHttpUrl` in `form_validators.dart` on `EventFormScreen` (#13). Mobile stores/sends `starts_at` as UTC (`toApiInstant`); all event UI uses `core/time/app_date_time.dart` for local display (#4). Lists reload after create via `CalendarRepository` + FAB `push` result (`#398`). |
| GET, PATCH, DELETE | `/v1/babies/{id}/events/{event_id}` | JWT; PATCH normalizes `video_call_url` when present |
| PUT | `/v1/babies/{id}/events/{event_id}/rsvp` | JWT (member); body `{status}` |
| POST, PATCH, DELETE | `/v1/babies/{id}/events/{event_id}/comments` | JWT (member); same comment capability flags as photo comments (FR-CAL-005) |
| GET, POST | `/v1/babies/{id}/registry/items` | JWT (member read; owner create). Optional `product_url`: same URL rules as calendar `video_call_url` (#13); mobile `RegistryItemFormScreen`. |
| GET, PATCH, DELETE | `/v1/babies/{id}/registry/items/{item_id}` | JWT; no PATCH when purchased; PATCH normalizes `product_url` when present |
| POST, DELETE | `/v1/babies/{id}/registry/items/{item_id}/purchase` | JWT (claim / undo) |
| GET, PATCH | `/v1/babies/{id}/registry/shipping-address` | JWT member read; owner PATCH. Body/response: `line1`, `line2`, `city`, `region`, `postal_code`, `country_code` (ISO-2), `formatted` (display). Save requires line1, city, postal_code, country_code; all null clears address. Mobile: `RegistryShippingAddressScreen` uses `Form` + `form_validators.dart` + `AppLabeledTextFormField` / `AppCountryDropdownField` (autovalidate after first submit). |
| GET, POST, DELETE | `/v1/babies/{id}/fun/names` | JWT (member); follower 1 name/gender; each suggestion includes `can_delete` (owner or author); mobile renders remove from that flag (#16) |
| POST | `/v1/babies/{id}/fun/names/{id}/like` | JWT; one like per gender column |
| GET | `/v1/babies/{id}/fun/predictions` | JWT. Tallies, viewer votes, voters, histogram, and `predictions_closed` (true when `baby_profiles.lifecycle_status` is `born`; a birth-announcement keepsake alone does not close votes) |
| PUT | `/v1/babies/{id}/fun/predictions/gender`, `.../birthdate` | JWT; birthdate upsert while expecting. When the baby is born, both a new vote and a change return **409** `{error: predictions_closed, message: Predictions closed — baby has arrived}` and do not write a vote or activity. Name suggestions stay open. Mobile hides gender taps, the calendar day selection, and **Save guess** / **Pick date…**, and shows that note; existing votes and tallies stay visible. Birthdate draft rules in `features/fun/domain/birthdate_prediction.dart` (never defaults a vote to the profile due date — #5) |

Local API env: `services/api/.env.example`. DB password and Mailjet keys live in **Secret Manager**.

**Local API tests** (after `pip install -r services/api/requirements-dev.txt` in `services/api/.venv`):

```bash
cd services/api
PYTHONPATH=src .venv/bin/pytest -q
```

Covers gallery/calendar/registry/fun domain rules (`services/api/tests/`).

**Auth verification and password-reset email (FR-AUTH-002 / FR-AUTH-007):** Firebase sends both from `packages/firebase-auth-email-templates` (`verify_email.*`, `reset_password.*`). `%APP_NAME%` is the OAuth brand **public-facing name** (`clientauthconfig` `applicationTitle`), which exists after Google sign-in is enabled. It is not the GCP project name and not the Firebase `displayName`. `bash scripts/configure-firebase-auth-email-project.sh apply` then `check` sets GCP name, Firebase display name, and brand title to **La Nonna** (idempotent). If no brand exists, enable Google sign-in in the Firebase console with public-facing name **La Nonna** — do not create a brand with the IAP brands API (those brands are internal-only). `bash scripts/sync-firebase-auth-templates.sh check` validates the files with no credentials. `check-remote` and `apply` compare live Identity Toolkit config and patch only drifted sender, subject, and body. `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED` is a Google lock: follow [`scripts/firebase-auth-template-support-request.md`](../../scripts/firebase-auth-template-support-request.md). Once the public-facing name is **La Nonna**, the default subject “Verify your email for %APP_NAME%” already reads correctly even if the custom HTML stays locked. Custom sender domain (SPF/DKIM) is deferred. Mobile uses `ActionCodeSettings` (`handleCodeInApp`, continue URL `https://{project}.firebaseapp.com/email-verified` from [`auth_link_config.dart`](../../apps/mobile/lib/core/auth/auth_link_config.dart)) and handles `https://lanonna-dev.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=…` via `core/deep_links/auth_action_app_link.dart` + Android/iOS link config. After verify in a **desktop browser**, Firebase redirects to that continue URL; Firebase Hosting serves [`hosting/public/email-verified/index.html`](../../hosting/public/email-verified/index.html) (root `/` rewrites there for older emails). Deploy with `bash scripts/deploy-invite-hosting.sh`.

**Product HTML typography:** Firebase Hosting (`/invite`, `/email-verified`), in-app legal WebViews (`apps/mobile/assets/legal/`), and transactional HTML (`packages/firebase-auth-email-templates/`, `packages/email-templates/invite_v1.html`) use **Baloo 2** for headings and the **La Nonna** wordmark (same as [`onboarding_logo_mark.dart`](../../apps/mobile/lib/features/onboarding/presentation/widgets/onboarding_logo_mark.dart)), and **Inter** for body copy, loaded from Google Fonts (Hosting shares [`hosting/public/css/lanonna-type.css`](../../hosting/public/css/lanonna-type.css)). Many webmail clients ignore web fonts and fall back to system sans-serif.

**Invite emails (FR-INV-004 / FR-INV-007 / #39 / #62):** batch create publishes `{"type":"send_invite_email",…}` to **`lanonna-async-commands`**; per-row **`email_queue_failed`** if Pub/Sub queue fails after the invite row is saved. A pending invite for the same email that was never delivered (`email_sent_at` null) is **resent** instead of **`skipped_duplicate`**. Owners can **`POST …/invitations/{id}/resend`** from Manage followers. The worker records `email_delivery_status`, `email_last_error`, and `email_send_attempts` (migration `034`); transient Mailjet/network errors return HTTP **500** for Pub/Sub backoff, permanent failures ack **204** with `email_delivery_status = failed`. Push subscriptions use exponential backoff in `pubsub.tf`. Worker sends Mailjet HTML from `invite_v1` templates; role-specific subject/body via [`invite_email_copy.py`](../../services/worker/src/lanonna_worker/invite_email_copy.py) (`{{invite_intro_text}}` / `{{invite_intro_html}}` — co-owner vs follower, aligned with in-app invite landing). User-derived HTML fields are escaped in the worker before send. Worker env `INVITE_DEEP_LINK_BASE` is an **https origin with no path** (dev deploy sets `https://lanonna-dev.firebaseapp.com`). Link shape: `https://{host}/invite?token=…` (+ `&role=owner` for co-owner). `lanonna://app/invite-accept?token=…` is only used when the base is explicitly the custom scheme (local override). The token is not logged. Firebase Hosting (`hosting/`, `scripts/deploy-invite-hosting.sh`) serves the landing page, `assetlinks.json`, and the Apple association file, and rewrites `GET /v1/invitations/preview` to Cloud Run `api` on the same origin. The page does not print the token. Flutter `invite_app_link.dart` maps both the https URL and the custom scheme to `/invite-accept` (`app_links` sets GoRouter `initialLocation` on cold start and `go()` on warm opens). Android App Links: `autoVerify` intent-filter for `https://lanonna-dev.firebaseapp.com/invite`. iOS entitlements already include `applinks:lanonna-dev.firebaseapp.com`; universal links for `/invite` start working when `APPLE_TEAM_ID` is passed to the hosting deploy (the association file also keeps `/__/auth/action`). Local API can set `INVITE_EMAIL_PUBLISH_DISABLED=true` to skip Pub/Sub while testing accept/preview.

**Baby data export (NFR-DATA-001):** the worker job lifecycle stays in `baby_data_export.py` (claim, heartbeat, stale reclaim, orphan blob delete). Content is `lanonna_worker.export` (`export_version` 2): every baby-graph table is either collected or listed in `EXCLUDED_TABLES` with a reason (`export/coverage.py`). The JSON uses display names and `person_` ids, omits member emails and Firebase UIDs, and attaches V4 signed media URLs (up to 7 days) minted by `lanonna-worker` (`GCS_SIGNING_SERVICE_ACCOUNT`, self `roles/iam.serviceAccountTokenCreator`). The app’s download of `export.json` stays the 15-minute API URL. Export, event links, the update prompt, and Help open through [`openExternalLink`](../../apps/mobile/lib/core/platform/external_link_launcher.dart): a failed `launchUrl` (including `ACTIVITY_NOT_FOUND`) shows a snackbar with Copy link (#59). The export screen lists the v2 contents (profile, members, photos and comments, calendar and RSVPs, registry and purchases, name ideas, predictions, the announcement, and activity). Beta-scale single JSON bundle (see [open-gaps.md](open-gaps.md) if streaming is needed later). Postgres coverage: `services/api/tests/integration/test_baby_data_export_postgres.py`.

**Pre-beta device QA:** [pre-beta-qa.md](pre-beta-qa.md) (App Check, encode, cache, push, deep links, invite cold start).

**Cold-start invite QA (app must be killed first):**

- Android (https, the link in the email): `adb shell am start -a android.intent.action.VIEW -d 'https://lanonna-dev.firebaseapp.com/invite?token=TOKEN'`
- Android (custom scheme, still accepted): `adb shell am start -a android.intent.action.VIEW -d 'lanonna://app/invite-accept?token=TOKEN'`
- iOS Simulator: `xcrun simctl openurl booted 'https://lanonna-dev.firebaseapp.com/invite?token=TOKEN'`
- Expect `/invite-accept` → preview API → follower or co-owner onboarding. Mid-flow kill + relaunch without link should resume via stored `pendingInviteToken` (`AppSession.redirectFor`).
- Disable `DEV_AUTO_SIGN_IN_*` dart-defines when testing unsigned invite UX.

**GCS finalize:** display bucket events publish to **`photo-upload-finalized`** only (worker thumbnails).

**In-app + push notifications:** API `domain/notifications.py` publishes `notify_fan_out` or `notify_user` to **`lanonna-async-commands`**; the worker handles the same types on `POST /pubsub/push` and inserts `notifications` rows. **Instant FCM** only when `push_notifications_enabled` and `notification_digest=realtime`. **`daily`** digest: in-app inbox only (no batch push). **`weekly`** digest: one summary push (Sunday 14:00 UTC) via Cloud Scheduler → Pub/Sub `{"type":"weekly_notification_digest"}` on **`lanonna-async-commands`** (`./scripts/setup-weekly-digest-scheduler.sh`; optional manual `POST /cron/weekly-notification-digest` on worker).

| Trigger | Publisher | Audience |
|---------|-----------|----------|
| Photo ready | Worker after thumb | Baby members (excl. uploader) |
| Photo squish / comment | API gallery domain | Photo uploader |
| Calendar event created | API calendar | Baby members (excl. creator) |
| RSVP | API calendar | Event creator |
| Registry purchase claimed | API registry | Baby owners (excl. buyer) |
| Baby arrived (announce) | API home PATCH | Baby members (excl. owner) |
| Invite accepted | API accept | Inviter |

API local dev: `NOTIFY_PUBLISH_DISABLED=true`. Mobile: `firebase_messaging`, `PushNotificationService` → `PUT`/`DELETE /v1/me/device-tokens` on auth; opens FCM `data.deep_link` (and optional `data.baby_profile_id`) via `navigateAppDeepLink` in `core/router/deep_link_navigation.dart`. **Shell vs root:** tab destinations (`/gallery/photo/:id`, `/calendar/event/:id`, `/registry`, …) must use `GoRouter.go` so the indexed shell is not stacked twice; inbox/profile/settings use `push` on the root navigator. Inbox rows include `baby_profile_id` when present so multi-baby accounts load the right context before navigation. Worker SA: `roles/firebasecloudmessaging.admin` on dev if sends fail.

**Invite onboarding QA (FR-ONB-011):**

| Deep link role | Expected path after profile |
|----------------|----------------------------|
| `invited_role=follower` | S08 follower invite → auth → S09 relationship → S10 carousel → follower Home |
| `invited_role=owner` (co-owner invite) | S08 co-owner invite → auth → co-owner welcome → owner-style Home |

Preview includes `lifecycle_status` and birth dates for invite subtitles and carousel slide 4. Wrong Google/email account → `/onboarding/wrong-email`.

## Database

Apply every SQL file in `infra/db/migrations/` in lexicographic order (the [migrations README](../../infra/db/migrations/README.md) lists them all and is the single source for the current set). Cloud SQL Auth Proxy may use port **5432** or **5433** — set `DB_PORT` consistently (`apply_migrations.py` defaults to **5432**; Maestro, `clear_dev_test_data.py`, and `verify-dev-migrations.sh` default to **5433**). Cloud SQL via Auth Proxy + `infra/db/apply_migrations.py` or `psql -f` per file. Use the venv under `infra/db/.venv` (`pip install psycopg`) or any environment with `psycopg` installed.

| Script | Purpose |
|--------|---------|
| `apply_migrations.py` | Runs every `migrations/*.sql` in lexicographic order (DDL is idempotent; safe to re-run on dev) |
| `clear_dev_test_data.py` | Delete baby-domain rows for a test user; optional `--reset-onboarding` |
| `scripts/hard_delete_user.sh` | One-liner hard delete by email (SQL + GCS + Firebase); uses `infra/db/.venv` |

Set `DB_HOST`, `DB_PORT` (e.g. `5433` if 5432 is in use), `DB_PASSWORD`, and `DB_USER` / `DB_NAME` as needed (defaults match dev Cloud SQL via proxy).

## Performance

How to measure performance, what is already optimized, and a prioritized backlog. Manual encode/cache checks: [pre-beta-qa.md](pre-beta-qa.md). Offline expectations: [requirements.md](../product/requirements.md) (NFR-OFFLINE-001, FR-GAL-002).

### Goals

- Fast tab switches; gallery thumbs from disk cache; responsive home after baby switch (`HomeRepository.resolveSelectedBaby`).
- Paginated API reads, thumb-first feeds, FCM instead of polling ([platform-architecture.md](platform-architecture.md) principles 3–4 and 9).

### How to measure

| Layer | Tool | Watch |
|-------|------|--------|
| Flutter | DevTools; `flutter run --profile` | Gallery jank; home rebuild scope |
| API | Cloud Run latency/5xx; request ID logs | p95 on `home-summary`, gallery list, `photos/init` |
| DB | Query Insights; `EXPLAIN` | Scans on `activity_events`, `photos` |
| GCS | Billing egress | Thumb vs display read ratio |

Baseline on **profile/release** build (`flavors/dev.json`): cold start → home → scroll gallery → calendar month change.

### Already optimized

| Area | Implementation |
|------|----------------|
| Cold start | [`AppVersionGate`](../../apps/mobile/lib/core/version/app_version_gate.dart) checks `/v1/app/version` in the background (5s timeout); onboarding carousel shows without waiting. Signed-in [`AppSession.refreshFromApi`](../../apps/mobile/lib/features/onboarding/presentation/app_session.dart) runs after first frame ([`LaNonnaApp`](../../apps/mobile/lib/app.dart)); router uses cached onboarding status until fresh. Debug App Check token logging is non-blocking. |
| Tab refresh | Split `HomeRefreshSignal` (`homeTab` vs `babyContext`); SWR shell tab loads (`TabLoadGenerationCache`); gallery `GalleryRepository` notify refreshes loaded pages only (keeps scroll); photo detail opens on `fetchPhoto` then pages swipe ids |
| Upload | `display_encode.dart`; ~2 MB cap in `storage.py` |
| Feed/detail | Worker thumbs; signed read URLs (900s TTL); `CachedSignedImage` + optional `onSignedUrlError` |
| Pagination | Gallery list; home activity limits; capped `home-summary` teasers |
| Notify | `safe_enqueue_fan_out` after DB commit |
| Rate limits | Photo init + invite batch (`rate_limit.py`) — per-instance; see [open-gaps.md](open-gaps.md) M-09 |

### Backlog (pick one per cycle)

1. **P0:** Stable `cacheKey` on remaining `CachedSignedImage` call sites; trim `home-summary` if profiling shows bloat. Done: tab SWR (`TabLoadGenerationCache`), calendar month cache + AI dedupe via month/upcoming, home-summary per-baby cache, event cover `event-cover-{photoId}`.
2. **P1:** ListView.builder for long lists; batch signed URL work in `build_home_summary` if needed.
3. **P2:** Offline banner + coalesced fetches (`ConnectivityService`, `BabyContextReload`).
4. **P3:** CDN at scale; optional archive tier for originals.

```bash
cd apps/mobile && flutter run --profile --dart-define-from-file=flavors/dev.json
./scripts/verify-dev-prerequisites.sh
```

## Related reading

- [operations.md](operations.md) — Terraform, deploy, migrations, dev gate, ship APK
- [open-gaps.md](open-gaps.md) — pre-beta blockers
- [platform-architecture.md](platform-architecture.md) — principles, flows, cost
- [pre-beta-qa.md](pre-beta-qa.md) — device QA checklist
