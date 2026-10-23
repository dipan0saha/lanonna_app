# La Nonna — Product Requirements Document

| Field | Value |
|-------|--------|
| **Version** | 1.0 (draft) |
| **Status** | Authoritative product spec for greenfield La Nonna (`lanonna_app`) |
| **Audience** | Product, design, mobile and backend engineering |
| **Last updated** | 2026-10-16 |

## 1. Document control

### 1.1 Purpose

This document defines **what** La Nonna must do for end users on the **Path B GCP** stack documented in [platform-architecture.md](../engineering/platform-architecture.md). Implementation details belong in architecture and migration docs, not here.

### 1.2 Related documents (La Nonna)

| Document | Role |
|----------|------|
| [platform-architecture.md](../engineering/platform-architecture.md) | Target stack, media pipeline, security, ops |
| [operations.md](../engineering/operations.md) | Dev readiness gate, deploy, and ship |
| [development.md](../engineering/development.md) | Repo layout and conventions |
| [product/README.md](README.md) | Index for this folder |

---

## 2. Product summary

**La Nonna** is a mobile app for families to share a pregnancy and baby journey with a trusted circle.

- **Owners** (including co-owners invited as owners) create and manage a **baby profile**, upload photos, run a calendar, maintain a gift registry, and invite followers.
- **Followers** see content across babies they follow, interact socially (squish photos, comment), RSVP to events, claim registry items, and participate in pre-birth predictions and name suggestions.

The experience is **role-aware**: owners see edit controls and baby-scoped management; followers see read-oriented views with permitted actions. A user may be an **owner** for one baby and a **follower** for others (**dual-role**); the app must keep **selected baby context** consistent across the shell.

---

## 3. Goals and principles

### 3.1 Goals

- Ship **v1 product scope**: onboarding, baby profile, home hub, gallery, calendar, registry, gamification, notifications, settings, profile, and deep links.
- **Secure, API-mediated data**: all domain reads and writes through the authenticated La Nonna API (see [platform-architecture.md](../engineering/platform-architecture.md)).
- **Photos**: client prepares a display-sized upload; feed uses thumbnails; detail uses the display asset (see platform doc §2.5).
- **Clear navigation**: fixed home sections and tab screens defined in this document (§6), not remote layout configuration.

### 3.2 Principles

- **Notify, don’t poll** for feed updates where possible (push + pull-to-refresh); see platform architecture.
- **Deep links and push** open the correct screen with an entity id in the URL (hybrid screen pattern).
- **English** copy for every user-facing string (externalized in localization files).
- **Email-first invitations** in v1; shareable links, SMS, contacts, and QR are later (§10.2).

---

## 4. Personas and roles

### 4.1 Roles

| Role | Capabilities |
|------|----------------|
| **Owner** | Full access to a baby profile they own: edit profile, calendar, registry, photos; manage followers and invitations; mark registry items as purchased (closes item to further claims); delete any registry purchase on their baby; see owner-only home sections (checklist, invite status). |
| **Follower** | Read access to followed babies; squish and comment on photos; RSVP and comment on events; purchase/claim registry items (one purchase per item); submit predictions and name suggestions. |
| **Co-owner** | Onboarded via invitation that grants **owner** membership and a relationship label (e.g. spouse); same capabilities as owner for that baby. |

### 4.2 Dual-role users

When the user holds both owner and follower memberships:

- Provide a **baby profile switcher** in the home app bar (and consistent selected profile across tabs where data is baby-scoped).
- Switching profile **reloads home content** for the new context without error (see FR-HOME-002).

### 4.3 Authorization model (requirements)

La Nonna must enforce **permission rules in API domain services** before any read or write (no direct database access from the client):

- Membership role and `removed_at` / soft-delete flags gate access.
- Followers cannot mutate owner-only resources (baby edit, event create, registry item create, etc.).
- Registry: at most **one purchase row per registry item**; owners may mark items as purchased and delete any purchase on their baby.
- Invitations: preview without auth; accept only when authenticated user email matches invitee email.

---

## 5. Brand and UX baseline

### 5.1 Visual design

Onboarding, authentication, and the signed-in shell share **one** light brand theme. Do not use a separate onboarding theme or per-route `Theme` overrides. `ThemeMode` is **light** only; Settings does not offer dark mode, accent pickers, or font pickers.

**Foundation**

| Concern | Requirement |
|---------|-------------|
| Material | Material 3 (`useMaterial3: true`) |
| Theme assembly | Central `ThemeData` with component themes (app bar, cards, buttons, inputs, bottom nav, chips, dialogs) |
| Tokens | Named brand palette + semantic colors exposed via `ThemeData.colorScheme` and a **brand theme extension** (sage/peach tints + success/warning/info) |
| Layout metrics | Shared spacing and radii for onboarding and in-app surfaces (horizontal page padding, card radius, pill buttons, carousel dots) |
| Contrast | Palette chosen for **WCAG 2.1 Level AA** for primary text on surfaces and CTA labels on sage fills |

**Color tokens**

| Token | Hex | Use |
|-------|-----|-----|
| Sage (primary) | `#A8C99B` | Primary buttons, key accents, `colorScheme.primary` |
| Sage dark | `#7FAE6E` | Links, focus accents, home app bar title, active carousel indicator |
| Sage tint | `#EAF3E4` | Insight cards, icon backgrounds, light fills |
| Peach (secondary) | `#F5B99B` | Secondary accents, `colorScheme.secondary` |
| Peach dark | `#EF9F76` | Bottom nav **selected** item, notification highlight dot |
| Peach tint | `#FCE8DC` | Warm cards and soft gradients |
| Scaffold background | `#F6F6F7` | App-wide scaffold |
| Surface | `#FFFFFF` | Cards, sheets, app bar background |
| Text primary | `#2D2D2D` | Headlines and body on surface |
| Text muted | `#9B9B9B` | Supporting copy, `bodyMedium` / helper text |
| Border / divider | `#E9E9EA` | Card outlines, dividers, input borders |
| CTA on sage | `#1C2E17` | Label on filled primary (sage) buttons |
| Nav inactive | `#B0B0B2` | Bottom nav unselected icon/label |

Semantic success, warning, info, and error use dedicated tokens on the brand extension. Destructive actions use `colorScheme.error`; avoid raw `Colors.red` / `Colors.green` in product UI.

**Typography**

| Role | Font | Spec |
|------|------|------|
| Body, labels, inputs, buttons | **Inter** (Google Fonts) | Support text ~14.5px, line height ~1.45; labels ~15px semibold on CTAs |
| Display / headlines | **Baloo 2** | Onboarding headlines and app bar titles ~24px bold, line height ~1.15; smaller headlines ~20px bold |

**Components (onboarding-aligned)**

| Component | Spec |
|-----------|------|
| Primary CTA | Filled **sage**, pill shape (radius 999), min height **52px**, horizontal padding 24px; label **CTA on sage** |
| Secondary CTA | Outlined pill with border `#E9E9EA`; same min height and padding as primary |
| Text fields | Corner radius **12px**; labels and hints use Inter; focused border/accent **sage dark** |
| Cards / hero surfaces | White surface, **16px** corner radius, **1px** border `#E9E9EA`, no elevation shadow; content padding ~18px; horizontal margin ~16px |
| Onboarding page layout | Horizontal content padding **26px**; carousel page indicators — inactive dot 7px; active indicator **20×7px** pill in **sage dark** |
| App bar | Elevation 0, centered title, white background, dark status bar icons; title uses brand headline styles |
| FAB | Uses primary sage family per global FAB theme |

**Shell chrome (same theme as onboarding)**

| Element | Spec |
|---------|------|
| Bottom navigation | Selected: **peach dark**; unselected: **nav inactive** |
| Home app bar title | **Sage dark** (not primary sage) |
| First-run / notification dot | **Peach dark** |

**How to build new UI**

1. Read colors from `Theme.of(context).colorScheme` and the brand theme extension — not scattered hex literals.
2. Use shared layout metrics for onboarding-style spacing, card radius, and button sizing on home sections and forms.
3. Reserve hard-coded hex only for third-party brand assets (e.g. social sign-in icons).

### 5.2 Shell navigation

- **Bottom navigation** with five destinations, in order: **Home**, **Gallery**, **Calendar**, **Registry**, **Fun** (gamification).
- **Tab roots** (the five bottom-nav screens) use `ShellTabLayout` and include the **home top bar** (add baby, invite family, baby switcher/title, notifications bell, account avatar).
- **All other signed-in content screens** — tab drill-downs (e.g. gallery photo, calendar event detail, registry edit), account/settings stack routes, and invite subpages — use a **single** subpage header (**back** + centered **title**) only; **no** stacked home top bar (same principle as FR-INV-008; see FR-SHELL-001).
- **Profile** and **Settings** are **stack screens** (`/profile`, `/settings`, `/account/edit`; deep links may use `/profile/edit`, normalized to `/account/edit`), reached from the shell app bar or account menu — they are **not** bottom-nav tabs.
- **Offline**: When the device is offline, show a **banner**; retain last-loaded content; suppress per-section error UI that would spam the home scroll.

### 5.3 Accessibility and forms

- Touch targets and form validation consistent with Material patterns.
- Support **biometric sign-in & unlock** on profile (`biometric_unlock_enabled`): hardware-backed challenge–response sign-in after logout, plus app lock while a Firebase session exists.

---

## 6. Information architecture

### 6.1 Home and tabs

- **Home** is a **fixed-order scrollable screen** of **sections** (cards, lists, teasers).
- **Calendar, Gallery, Registry, and Fun** screens own full lists and detail flows.
- Section **visibility** follows **product rules** (e.g. hide countdown after birth), implemented in Flutter and/or API responses.

### 6.2 Home sections (owner context)

Recommended vertical order (adjust in design wireframes without dropping capabilities):

1. **New baby welcome** — birth announcement card; owner only; visible up to **7 days** after `actual_birth_date`.
2. **Due date countdown** — pre-birth only; hidden after birth recorded.
3. **Onboarding checklist** — owner setup tasks until complete or dismissed per product rules.
4. **System announcements** — dismissible banners (global or targeted).
5. **Upcoming events** — teaser list; “View all” → `/calendar/upcoming`.
6. **Recent photos** — grid teaser; “View all” → `/gallery/recent`.
7. **Activity recap** — **full stream** of recent `activity_events` (chronological audit-style feed), not a weekly rollup.
8. **New followers** — joined in last 30 days; owner only.
9. **Invite status** — pending email invites; revoke; owner only.

RSVP, gallery favorites, registry highlights/purchases, and notification preview are **not** on Home; use Calendar, Gallery, Registry, and the notification inbox (bell) instead (#67).

### 6.3 Home sections (follower context)

Same components where applicable, with **aggregated or read-only** data across followed babies. Omit owner-only sections (checklist, invite status). Editing controls hidden.

### 6.4 Feature screens (full flows)

Retain route-level flows documented in Appendix B: auth, onboarding, baby profile CRUD, followers management, gallery subviews, photo detail, calendar CRUD and RSVP, registry CRUD and purchase, gamification hub, settings, user profile.

### 6.5 Onboarding flows (high level)

| Path | Steps after authentication |
|------|----------------------------|
| **Owner** | Carousel → signup/login → email verify → complete profile → create baby → first moment (optional preset events/registry) → batch invite → Home; **main app** only after `owner_onboarding_completed` (not merely profile + baby) |
| **Follower** | Invite accept → invite preview → signup/login → complete profile → confirm relationship → follower carousel → Home |
| **Co-owner** | Invite accept (owner role) → co-owner invite screen → signup/login → complete profile → co-owner welcome → Home |

Rules:

- Cold-start **invite and auth deep links** captured before first frame; resume correct onboarding step after restart (`onboarding coordinator` behavior).
- Completed onboarding **cannot** return to `/onboarding/*` routes.
- **Wrong email** path when invite email does not match signed-in account.

---

## 7. Functional requirements

Each requirement has an ID for traceability. **Implementation note** describes the La Nonna stack where helpful.

### 7.1 Authentication — FR-AUTH

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-AUTH-001 | Email/password sign-up and sign-in | User can register and sign in; invalid credentials show clear error | Firebase Auth |
| FR-AUTH-002 | Email verification in onboarding | After email/password sign-up, user receives a **La Nonna–branded** Firebase verification email (subject **Verify your email for La Nonna**, sender display name **La Nonna**, HTML from `verify_email.html` with a tappable **Verify my email** CTA (`%LINK%`)); unverified users stay on the verify screen until `emailVerified` or they tap Continue after verifying in mail; app handles `https://{project}.firebaseapp.com/__/auth/action` links in-app when installed (`ActionCodeSettings` continue URL `https://{project}.firebaseapp.com/email-verified`, Hosting page at `hosting/public/email-verified/`); resend and rate-limit errors show clear copy; verify screen does not show Google-specific skip copy (Google sign-in never routes there) | `%APP_NAME%` is the OAuth brand **public-facing name** (`applicationTitle`), not the GCP project name. `scripts/configure-firebase-auth-email-project.sh` sets that title plus the GCP and Firebase display names. `scripts/sync-firebase-auth-templates.sh` (`check` local, `check-remote` / `apply` live) patches Identity Toolkit subject, body, and sender. Product HTML typography: [development.md](../engineering/development.md). If Google returns `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`, escalate with `scripts/firebase-auth-template-support-request.md`. Custom auth **sender domain** (SPF/DKIM) deferred |
| FR-AUTH-003 | Session persistence | Returning users with valid session land on Home (or onboarding resume) | Firebase session + app router guards |
| FR-AUTH-004 | Sign out | Sign out clears Firebase session and local push identity hooks | `DELETE /v1/me/device-tokens` on sign-out (`PushNotificationService`) |
| FR-AUTH-005 | Unauthenticated guard | Cold launch without session shows sign-in (E2E-001) | GoRouter redirect |
| FR-AUTH-006 | Google sign-in | User can sign in or sign up with Google (v1); links to same Firebase user model as email | Firebase Auth Google provider |
| FR-AUTH-007 | Password reset | From sign-in, user can request a Firebase password-reset email branded the same way as verification (subject **Reset your password for La Nonna**, sender **La Nonna**, `reset_password.html`); pre-fills email when valid on the form, otherwise prompts; success shows “check your email”; reset links open via existing auth action deep-link handler | `reset_password.*` in `packages/firebase-auth-email-templates`, same sync script as FR-AUTH-002; `AuthRepository.sendPasswordResetEmail`; login **Forgot password?** + `auth_action_app_link` |

### 7.2 Onboarding — FR-ONB

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-ONB-001 | Owner carousel entry | New owners start at owner carousel when no session/onboarding complete | Fixed routes |
| FR-ONB-002 | Onboarding signup/login variants | Query `path=owner\|follower\|coOwner` selects copy and next routes | Flutter onboarding module |
| FR-ONB-003 | Complete profile (S04) | After signup/email verify: photo; first + last name; optional phone, user DOB, country (ISO), postal code; **owner path**: Mother/Father relationship (required client-side); terms unchecked by default with in-app WebView links to sample legal HTML; `profile_complete` when name + `terms_accepted_at` | `PATCH /v1/profile`; mock: [`Complete_Your_Profile_Screen_1.html`](../prototype/Archive/Complete_Your_Profile_Screen_1.html) |
| FR-ONB-004 | Create baby (onboarding) | Owner creates first baby; optional names (unnamed babies display **Baby** — a display fallback only, the name is stored as `NULL`), gender, expecting/born dates; when **expecting** with **gender unknown**, optional boy/girl first-name fields seed **Fun** via `profile_name_suggestions` (#400) and set default `baby_profiles.name` per #316 (both filled → creating owner's last name from complete profile when relationship is Mother/Father; boy-only or girl-only → that first name; no usable surname → `NULL`); optional **profile photo** sets `baby_profiles.avatar_url`; gallery only on opt-in; **`relationship_label`** from complete profile | `POST /v1/babies` + membership owner; mobile [`CreateBabyScreen`](../../apps/mobile/lib/features/baby/presentation/create_baby_screen.dart) |
| FR-ONB-005 | First moment | Optional preset event/registry chips and name ideas; skippable | `POST /v1/babies/{id}/onboarding/first-moment` |
| FR-ONB-006 | Batch email invite | Multiple invite rows; co-owner badges (Wife/Husband); skip row if email already member | API + `check membership by email` |
| FR-ONB-007 | Follower relationship confirm | Follower **views** owner-set relationship label (S09) before carousel; not editable by invitee | Invite preview `relationship_label` |
| FR-ONB-008 | Coordinator resume | Kill app mid-onboarding → resume same step; owner router blocks `/home` until `owner_onboarding_completed` | Local persistence of step/drafts; `GET /v1/onboarding/status` supplies `owner_onboarding_baby_profile_id` (rehydrated on refresh after sign-out); `OwnerOnboardingBabyResolver` for first moment and batch invite; `AppSession` guards |
| FR-ONB-009 | Deprecated role selection | `/role-selection` redirects to owner carousel | Router redirect |
| FR-ONB-010 | Owner UI prototype parity | Owner onboarding S04 matches `Complete_Your_Profile_Screen_1.html`; other owner steps (S01–S07) and first-run Home (S11–S12) align with onboarding prototype where not superseded; login mirrors signup stack; Facebook omitted | Flutter onboarding + home modules |
| FR-ONB-011 | Follower/co-owner invite onboarding | Follower S08–S10 + follower first-run Home; co-owner S08 + welcome; wrong-email screen; accept after complete profile; prototype copy (Facebook omitted) | `/invite-accept` bootstrap, invite path coordinator |
| FR-ONB-012 | User profile demographics | Optional phone, user birth date, country (ISO 3166-1 alpha-2), postal code on `app_users`; readable/editable on account | Migration `022`; `GET /v1/me/account` profile |
| FR-ONB-013 | Terms acceptance | Checkbox default off; Continue requires check; `terms_accepted_at` stored; Terms/Privacy open in-app WebView (sample legal assets) | `PATCH /v1/profile` `accept_terms: true` |

### 7.3 Invitations — FR-INV

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-INV-001 | Invitation preview | Token hash returns baby name, inviter, invitee email, relationship, role; `status` is `pending`, `accepted`, `revoked`, or `expired` (accepted includes baby fields so mobile can continue onboarding without treating the link as expired) | `GET /v1/invitations/preview`; `domain/invitations.py` |
| FR-INV-002 | Accept invitation | Email must match invitee; **idempotent** if already member (200 `already_member`) even when invite row is already `accepted`; first accept on pending creates membership and marks invite accepted | API transaction + domain policy |
| FR-INV-003 | Invitation errors | `email_mismatch`, `expired`, `revoked`, `already_used`, `max_owners`, `not_found` with user-safe copy. A baby has at most **2 owners**: batch invite does not create a co-owner invite that could never be accepted (active owners plus pending, unexpired co-owner invites fill the slots) and reports the row as skipped with ARB copy; accept refuses with `max_owners` when the baby already has 2 active owners | Coded domain errors (`ErrorCode`, `map_domain_errors`); `domain/owner_limit.py`; batch row status `skipped_max_owners`; mobile `invite_accept_messages.dart` maps `ApiErrorCode` to ARB copy |
| FR-INV-004 | Send invite email | Owner sends invite; pending row visible in management UI; **Resend** on Manage followers for pending invites | Pub/Sub `send_invite_email` on **`lanonna-async-commands`** + Mailjet HTML templates (Baloo/Inter HTML per [development.md](../engineering/development.md)). Batch API returns a typed per-row status (`created`, `resent`, `skipped_member`, `skipped_duplicate`, `email_queue_failed`) from one set-based check and one transaction; **`email_queue_failed`** means the invite row exists but email was not queued (owner may revoke and re-invite). Undelivered duplicate email re-queues send instead of `skipped_duplicate`. Worker persists `email_delivery_status`, `email_last_error`, `email_send_attempts` (migration `034`); transient failures retry via Pub/Sub **500**; permanent failures stop retrying. |
| FR-INV-005 | Revoke pending invite | Owner revokes; row removed from pending list (E2E-016) | API delete/cancel invite |
| FR-INV-006 | Membership check by email | Owner batch invite shows “Already a member” for existing emails | API check endpoint |
| FR-INV-007 | Deep link accept | Invite email uses `https://{project}.firebaseapp.com/invite?token=&role=` (co-owner adds `role=owner`). Installed Android opens the app via App Links; installed iOS opens it via Universal Links once an Apple Team ID is in the hosted association file. Without the app, the same URL shows a branded page with who invited them and how to install, then the link is opened again. Custom scheme `lanonna://app/invite-accept?token=` still opens the accept flow. The token is never written to application logs | Firebase Hosting `hosting/` (`scripts/deploy-invite-hosting.sh`); worker `build_invite_url`; `invite_app_link.dart` maps both URL shapes to `/invite-accept` |
| FR-INV-008 | Post-home batch invite UI | `/invite-family` matches main-app prototype **followers-invite**: single subpage header **Invite Family & Friends** (no stacked home top bar); intro copy on **14-day** private link (`AppMetrics.horizontalPadding`; API `invitations.expires_at`); sage co-owner hint with 💡 for **Mother/Father**; relationship picker uses Mother/Father (not Wife/Husband); **+ Add another person**; email-only send (v1) | `BatchInviteScreen` `fromHome` |
| FR-INV-009 | Remove member | Owner removes an accepted follower or (when ≥2 owners) another owner; soft `removed_at`; immediate loss of access; activity event; re-invite may reactivate membership (#25). RSVPs, prediction votes, name loves, and squishes on that baby are removed and are not restored when the membership is reactivated. Comments, photos, name suggestions, and registry claims stay. | `DELETE …/members/{uid}`; `domain/member_lifecycle.py` |
| FR-INV-010 | Leave profile | Member leaves a baby they follow or co-own; sole owner cannot leave (add co-owner and leave, delete baby per FR-BABY-007, or delete account); `can_leave` on baby list. The same presence rows on that baby are removed and are not restored on re-invite. Comments, photos, name suggestions, and registry claims stay. | `POST …/leave`; baby switcher + `BabySummary.can_leave` |

### 7.4 Baby profile — FR-BABY

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-BABY-001 | Create baby | Owner creates baby (onboarding first baby or in-app add); same name rules as FR-ONB-004 / #316 on [`CreateBabyScreen`](../../apps/mobile/lib/features/baby/presentation/create_baby_screen.dart) submit (onboarding revise + `/baby/create`); optional names (displayed as **Baby** while unnamed; never stored as a placeholder), gender, dates, avatar; in-app reuses same UI as FR-ONB-004 without first-moment/invite. **Edit baby** (`/baby/:id/edit`) uses a single baby-name field — not boy/girl #316 logic | `POST /v1/babies`; `PATCH /v1/babies/{id}` |
| FR-BABY-002 | Edit baby | Owner edits fields; clearing the name returns the baby to unnamed (shown as **Baby**) | `PATCH /v1/babies/{id}` (blank `name` clears) |
| FR-BABY-003 | Auto-select new profile | After create, home context switches to new baby (E2E-005) | Client state |
| FR-BABY-004 | Followers management | Lists active members (name or **Family member**, role, joined date, `can_remove` — no email or relationship on member rows) and pending invites; owner removes members with confirmation; revoke pending per FR-INV-005 | `/baby/{id}/followers`; `followers_screen.dart` |
| FR-BABY-005 | Invite from profile | Navigate to invite screen from management; UI per FR-INV-008 | `/invite-family` |
| FR-BABY-006 | Profile photo | Baby avatar upload uses display media policy | `baby_profiles.avatar_url` (`013`); owner baby edit and onboarding create-baby use display signed PUT + `PATCH /v1/babies/{id}`; gallery upload is separate (opt-in on create-baby, #394) |
| FR-BABY-007 | Delete baby profile | Sole active owner may permanently **hard-delete** the baby profile (`DELETE /v1/babies/{id}`): all baby-scoped SQL rows removed (photos, events, registry, comments, RSVPs, invites, etc.) and GCS objects purged asynchronously (same as sole-owned babies on account delete). Co-owned babies cannot be deleted (`409 cannot_delete_shared_baby`); the owner must **leave** instead. Mobile: **Delete baby profile** on Edit baby and in the baby switcher (sole owners); two-step confirmation; co-owners and followers keep **Leave profile** | `domain/baby_delete.py`; `repositories/baby_profile_delete.py`; `baby_edit_screen.dart`; `delete_baby_profile_flow.dart`; `baby_switcher_sheet.dart` |

### 7.5 Home hub — FR-HOME

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-HOME-001 | Section composition | All capabilities in §6.2–6.3 present as sections | Fixed Flutter layout |
| FR-HOME-002 | Profile switch reload | Changing selected baby refreshes home content and title (E2E-004) | `HomeRepository.resolveSelectedBaby`; baby-scoped tabs (home, gallery, calendar, upcoming, export, batch invite) |
| FR-HOME-003 | Pull to refresh | Home supports pull-to-refresh (E2E-021) | Client refresh |
| FR-HOME-006 | Calendar/registry refresh | Calendar, Registry, and Gallery tabs refresh after mutations and support pull-to-refresh (E2E-021); gallery list/teasers see FR-GAL-013 | Client refresh; gallery uses `notifyGalleryDataChanged` |
| FR-HOME-004 | Empty states | No baby profile shows CTA to create (E2E-020) | Empty state UI |
| FR-HOME-005 | Hide rules | Welcome/countdown/checklist follow §6.2 visibility rules | Client + API fields |
| FR-HOME-007 | Activity recap | Home teaser and `/home/activity` use the same **activity row** UI as Gallery (icon, localized sentence with the actor in bold, timestamp; the sentence is built in the app from the event type and its params, names fall back to **Family member**; a follower's registry claim stays anonymous); full stream from `activity_events` (paginated, all event types) | `ActivityFeedCard`; `GET …/activity-events` |

### 7.6 Gallery — FR-GAL

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-GAL-001 | Upload photo | Owner picks image; optional caption; success feedback (E2E-007) | `POST /v1/photos/init` + signed PUT to `display/` per [platform-architecture.md §2.4](../engineering/platform-architecture.md) |
| FR-GAL-002 | Display asset policy | Long edge ~2048px; WebP preferred; max size enforced at init | Flutter encode; API rejects oversize |
| FR-GAL-003 | Thumbnail ready | Feed shows thumb after worker processes finalize event | Pub/Sub worker → `thumbnails/` |
| FR-GAL-004 | Gallery views | Recent and favorites routes | `/gallery/recent`, `/gallery/favorites`; list API `sort=recent\|favorites\|default`; home teasers link “View all” |
| FR-GAL-005 | Photo detail | Fullscreen display asset; metadata and actions; mutations (squish, comments, caption) refresh in place without full-screen reload (`detail_screen_load.dart`) | `/gallery/photo/:id` |
| FR-GAL-006 | Squish | Toggle like; count updates (E2E-008) | API `photo_squishes` |
| FR-GAL-007 | Comments | Members create comments; author edits own; author or baby **owner** deletes (moderation); list includes `can_edit` / `can_delete`; comment author label is `app_users.display_name` (fallback **Family member**; never email — #7) | `photo_comments`; `domain/users_display.py`; `POST` / `PATCH` / `DELETE` on `…/photos/{id}/comments` |
| FR-GAL-008 | Tags | Owner tags other babies they belong to on a photo (metadata v1; no cross-feed). **Read:** `tagged_babies` on photo detail (and tag PUT response) lists only babies the **viewer** is a member of — followers never see names of profiles they were not invited to (#9) | `photo_baby_tags`; `list_tagged_babies_for_photo(photo_id, viewer_uid)` joins `baby_memberships`; `PUT .../photos/{id}/tags` |
| FR-GAL-009 | Pending visibility | Photos not visible to others until processing complete | SQL status + API filter |
| FR-GAL-010 | Owner edit caption | Owner can edit photo caption from detail (E2E-008) | API update; follower read-only |
| FR-GAL-011 | Gallery recent activity | On **Gallery** (all photos), section shows up to **6** gallery-scoped activity rows (`photo_squish`, `photo_comment`): prototype row UI (icon, summary, timestamp below, dividers); empty card copy when none; all members | `GET …/activity-events?scope=gallery`; `ActivityFeedCard` |
| FR-GAL-012 | Grid social badges | Photo tiles show comment and squish count chips when &gt; 0 | `GalleryPhotoGrid`; list API counts |
| FR-GAL-013 | Gallery list refresh | After upload, delete, squish, or comment, gallery routes and home photo teasers update without manual pull-to-refresh | `GalleryRepository` (`ChangeNotifier`); `notifyGalleryDataChanged`; `BabyContextReload` on shell tabs; upload polls by `photoId` for thumb ready |

### 7.7 Calendar — FR-CAL

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-CAL-001 | Event list/calendar views | Month grid on Calendar tab; tapping a day **selects** that date and shows a day-scoped event list (or empty + owner **Add event**); event detail only when a list row is tapped (never auto-navigate from day tap); **Show all** or changing month clears selection and restores **Today** (when non-empty) + **Upcoming** (later days via `upcoming=true`) | `eventsOnLocalCalendarDay`; `partitionCalendarListEvents`; current-month fetch |
| FR-CAL-002 | Create event | Owner creates event (E2E-009); after save, event appears on Calendar **Upcoming** when `starts_at` is in the future and on month grid by **local** date; nested create routes refresh list on return (`#398`) | `/calendar/event/create` |
| FR-CAL-003 | Event detail/edit | Detail by id; edit route for owner; optional cover photo is **not** a gallery share unless the owner picks an existing gallery photo (#315) | `/calendar/event/:id`, `.../edit`; `photos.purpose` = `event_cover` for new cover uploads |
| FR-CAL-004 | RSVP | Follower/owner RSVP yes/no/maybe; attendee list shows each member's `display_name` (#7); RSVP sheet shows localized status labels, not API codes (#18) | `event_rsvps`; `rsvp_display_name_from_row`; mobile `rsvp_status_labels.dart` |
| FR-CAL-005 | Event comments | Same moderation rules as FR-GAL-007 on event detail; comment field does not steal focus after returning from event edit (#17) | `event_comments`; `POST` / `PATCH` / `DELETE` on `…/events/{id}/comments` |
| FR-CAL-006 | Upcoming list | View all from home teaser (E2E-018); same Today + Upcoming grouping as Calendar tab | `/calendar/upcoming` |
| FR-CAL-007 | AI event suggestions | Static catalog by expecting/age tabs; shared “AI Suggestions” UX with registry; hide rows already added (`catalog_suggestion_id` on event); after add, brief info snackbar confirms save (`#398`) | `/calendar/ai-suggestions`; `event_suggestions.json` |
| FR-CAL-008 | Optional video call URL (#13) | Empty allowed; non-empty must be `https://` in every environment (bare domains normalized to `https://`; `http://`, `localhost` and dotless hosts rejected, #415); junk schemes rejected on save with user-visible message; API returns **400** on invalid URL | `url_validation.py`; `EventFormScreen`; `form_validators.dart` |

### 7.8 Registry — FR-REG

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-REG-001 | Item CRUD | Owner creates/edits/deletes items (E2E-010); add/edit form validates required item name inline; API errors via `runMutation` / `apiErrorMessage` (#8) | API + routes; `RegistryItemFormScreen` |
| FR-REG-002 | Follower purchase claim | Follower marks item via in-app “I’ll buy this”; only one purchase per item | Unique index on `registry_item_id`; `POST .../purchase` |
| FR-REG-003 | Owner undo purchase | Owner can delete any purchase to reset item | API delete |
| FR-REG-004 | Registry list on tab | Full list on Registry screen; **Needed** rows show item name/description at full card width with purchase/edit/delete actions on a separate row (#399) | Registry tab primary content |
| FR-REG-005 | Item detail/edit nav | Deep link and in-app nav (E2E-019) | `/registry/item/:id` |
| FR-REG-006 | Edit purchased item | Owner cannot edit item fields after purchase; can open detail; owner may reset via purchase delete (FR-REG-003) | API + UI guard |
| FR-REG-007 | Owner mark purchased | Owner/co-owner marks a needed item as purchased (e.g. gift bought off-app); item moves to Purchased; followers no longer see claim action; owner may undo (FR-REG-003) | Reuses `POST .../purchase`; Registry Needed UI |
| FR-REG-008 | AI registry suggestions | Static catalog by expecting/age tabs; shared `AiSuggestionsScaffold` with calendar; hide rows already added (`catalog_suggestion_id` on item) | `/registry/ai-suggestions`; `registry_suggestions.json`; migration `017` |
| FR-REG-009 | Registry shipping address (#408) | Owner edits structured address (street, city, optional region, postal, country) on dedicated screen; client `Form` validates required fields (inline errors clear on fix); followers read formatted address on Registry tab; owner may clear | `baby_profiles.registry_shipping_*`; `GET/PATCH .../registry/shipping-address`; `/registry/shipping-address`; migration `023` |
| FR-REG-010 | Optional item link (#13) | Same URL rules as FR-CAL-008 for registry `product_url` | `RegistryItemFormScreen`; API registry create/PATCH |

### 7.9 Gamification — FR-GAM

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-GAM-001 | Gender prediction | Follower votes male/female and can change the vote while the baby is expecting; once `lifecycle_status` is `born`, a new vote or a change returns HTTP 409 `predictions_closed` and the Fun tab is read-only with “Predictions closed — baby has arrived”; existing votes and tallies stay visible; zero votes show 0% and no misleading 50% bar (#22) | `votes` vote_type gender; `GET …/fun/predictions` `predictions_closed`; mobile `gender_vote_display.dart`, `PredictionsTab` |
| FR-GAM-002 | Birthdate prediction | Follower explicitly selects a calendar day (profile due date is highlight only, never auto-submitted); confirm before save; can change the guess later while expecting (#5); the same born close as FR-GAM-001 applies to birthdate votes and changes | `votes` vote_type birthdate; mobile `features/fun/domain/birthdate_prediction.dart`; `PredictionsTab` draft + single submit; hidden when `predictions_closed` |
| FR-GAM-003 | Identified predictions | Gender/birthdate votes attributed to the member; visible in who-voted lists | `votes.is_anonymous` legacy only; new votes stored identified |
| FR-GAM-004 | Name suggestions | Submit suggestions with gender scope (non-owners: one per gender); author may remove own suggestion; owner may remove any; list includes `can_delete`; expecting create-baby profile names auto-seed on baby create (#400); stored/displayed names preserve user casing (McKenzie, hyphenated names); API rejects duplicate names per gender case-insensitively (#12); server limit/errors shown via `runMutation` (#8); once `lifecycle_status` is `born`, suggest/remove return HTTP 409 `fun_closed` and the Names tab stays **visible read-only** (names and loves remain) | `name_suggestions`; `GET …/fun/names` `can_delete`, `names_closed`; mobile `AppTextInputKind.personName`; `find_name_suggestion_case_insensitive` |
| FR-GAM-005 | Name likes | Like others’ suggestions; closed after birth like FR-GAM-004 (409 `fun_closed`) | `name_suggestion_likes` |
| FR-GAM-006 | Fun tab hub | Gamification screen hosts suggestions + predictions (E2E-011) | `/gamification` |
| FR-GAM-007 | User stats | Aggregated counts for recap | `user_stats` via triggers or API |

### 7.10 Notifications — FR-NOTIF

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-NOTIF-001 | In-app inbox | Bell (or equivalent) opens full notification list; mark read and **mark all read**; each row shows a type icon and a localized sentence built in the app from the notification kind, its params and the actor name (structured server fields, never parsed from copy; RSVP rows say going / might go / can't make it); deep links include `baby_profile_id` when present | `notifications` table (`notification_type`, `notification_kind`, `params`, `actor_display_name` — migrations `036`/`037`/`038`); `GET/PATCH` inbox routes, `POST /v1/me/notifications/read-all` |
| FR-NOTIF-002 | Push delivery | New photo, RSVP, etc. respect user prefs. Push text is English, rendered by the worker from one catalog (`push_copy`) because the OS shows push notifications without running the app | Worker FCM when `push_notifications_enabled` and digest **`realtime`**; **`daily`** = inbox only; **`weekly`** = summary push (Scheduler) |
| FR-NOTIF-003 | Deep link payload | Push/inbox/home preview opens the correct screen (including nested tab routes) | FCM `data.deep_link` + optional `baby_profile_id`; client `navigateAppDeepLink` uses **`go`** for shell tab paths (`/home`, `/gallery`, …) and **`push`** for root routes (`/notifications/inbox`, `/profile`, …); switches selected baby when `baby_profile_id` differs |
| FR-NOTIF-004 | Preferences | Per-channel toggles in settings (E2E-014 partial) | `GET/PATCH /v1/me/notification-preferences`; `notify_*_enabled` on `app_users` (`gallery`, `calendar`, `registry`, `comments`); worker gates inbox + FCM |

### 7.11 Profile and settings — FR-PROF, FR-SET

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-PROF-001 | View profile | User sees display name, avatar, stats | `/profile` from shell menu |
| FR-PROF-002 | Edit profile | Update display name, avatar, optional demographics (phone, DOB, country, postal). First and last name are required (same validators as complete-profile; a blank name is not saved as "Account"). Optional phone uses the shared rule (digits, spaces, `+ - ( )`, 7–20 digits, at most one leading `+`); the form and `PATCH /v1/profile` both reject anything else. After Save, My Account shows the new name immediately | `/account/edit` |
| FR-PROF-003 | Storage usage | Owner sees media allocation meter (used vs quota across owned babies) | `/profile`; `GET /v1/me/account` → `storage_usage` |
| FR-SET-001 | Settings screen | Notification prefs, help/support entry, optional **biometric sign-in & unlock** toggle (device key enrollment + `biometric_unlock_enabled` via `PATCH /v1/profile`) | `/settings`; `BiometricAppLock` when signed in (cold start / resume on main-app routes; injected `GoRouter` — [rca/biometric-app-lock-never-engages.md](../engineering/rca/biometric-app-lock-never-engages.md)); **Sign in with biometrics** on login when device enrolled; challenge–response + Firebase custom token (PRD §5.3 / M-31) — see [rca/biometric-signin-after-logout.md](../engineering/rca/biometric-signin-after-logout.md) |
| FR-SET-002 | Language | **English only**; copy in ARB/localization files (no hardcoded UI strings — enforced in CI by the AST guard `apps/mobile/tool/check_hardcoded_user_strings.dart`; server enum values shown through localized labels, never raw). No Spanish or other locales in product scope. Count labels use ICU `plural` in ARB (e.g. squish/comment/vote/love/registry teaser — #11). Calendar **dates** (due date, birthdate guesses, baby switcher) use `formatApiCalendarDate`, not raw ISO (#19). Onboarding/registry **forms**: after first failed submit, enable `AutovalidateMode.onUserInteraction` on `Form` and fields so fixing input clears errors without a second submit (#21). | `app_en.arb`; `tool/check_hardcoded_user_strings.dart`; `app_date_time.dart`; `onboarding_login_screen` / registry shipping pattern |
| FR-SET-003 | No dark mode picker | Theme remains light only | Product decision (light-only brand) |
| FR-SET-004 | Minimum app version | Below minimum: **hard block** — full-screen prompt; only action is open store / update | Reads `app_versions`; no dismiss |
| FR-SET-005 | Delete account | User opens `/account/delete` (the screen states the consequences), then confirms in a second dialog. That dialog lists sole-owned babies from **`GET /v1/me/delete-account/preview`** (`sole_owned_babies`; an unnamed baby is listed as **Baby**). Deletion is never blocked, so there is no eligibility or blockers contract. Password accounts re-enter their password and Google accounts sign in again before the delete call. Mobile loads the preview when the screen opens. Account is permanently deleted (Firebase user removed, SQL profile tombstoned). **Sole-owned** baby profiles are **hard-deleted** with the account (all baby-scoped SQL data removed; GCS cleanup async). **Co-owned** baby profiles remain; deleting user’s owner membership is removed and remaining owner(s) retain full ownership. Photos the user uploaded on co-owned babies they follow are removed. Confirmation copy states account deletion, sole-owned baby removal, co-owned retention, and shared-baby photo removal. **After delete:** API rejects authenticated requests for that Firebase UID with **401 `user_deleted`** (even if the ID token is still valid); `upsert_app_user` must not restore scrubbed email; mobile signs out on that code (#30). RSVPs, prediction votes, name loves, and squishes from the deleted account are removed on babies they still had access to. On **co-owned** babies, comments and name suggestions remain under the anonymized profile; on sole-owned babies those rows are deleted with the baby. | `GET/POST /v1/me/delete-account/*`; `domain/auth_session.py`; [rca/baby-hard-delete.md](../engineering/rca/baby-hard-delete.md) |

### 7.12 Deep linking — FR-DEEP

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-DEEP-001 | ID-embedded routes | Gallery, calendar, registry detail/edit use `:id` paths | GoRouter |
| FR-DEEP-002 | Hybrid screens | Pass entity via navigation `extra` OR fetch by id on cold link | Detail screens |
| FR-DEEP-003 | Route ordering | Static `create` routes before `:id` siblings | Router config |
| FR-DEEP-004 | Cold-start capture | Invite links set initial route before `runApp` | Deep link service |

### 7.13 Shell chrome — FR-SHELL

| ID | Requirement | Acceptance criteria | Implementation note |
|----|-------------|---------------------|---------------------|
| FR-SHELL-001 | Subpage header only | Tab drill-downs, settings/account stack, and invite subpages show back + title; home top bar appears only on tab roots; My Account uses subpage scaffold with bordered tiles inset to `AppMetrics.horizontalPadding` (26px); home and subpage blocks use consistent section title→content rhythm (`sectionTitleGap`, `HomeScrollSection` / `AppSectionTitle`) | `ShellTabLayout` + `shellHomeTopBar`; `PrototypeSubpageScaffold` for subpages; `AppBorderedSurface` + `subpageScrollPadding`; `HomeScrollSection` / `AppSectionTitle` (see §5.2, FR-INV-008, #410) |

### 7.14 Background jobs

| Job | Requirement |
|-----|-------------|
| Invite email | Worker/API + Mailjet (FR-INV-004) |
| Push notification | Pub/Sub `notify_fan_out` / `notify_user` → worker → SQL inbox + FCM (FR-NOTIF-002) |
| Thumbnail generation | GCS finalize → Pub/Sub → worker thumb ~320px width |
| Image metadata | Client EXIF/dimensions at encode; API may validate |
| Notification digests | **Weekly:** Cloud Scheduler → Pub/Sub `weekly_notification_digest` → worker summary FCM. **Daily:** in-app only (no scheduled push in v1). |

### 7.15 Invitation API operations

The API must support these invitation flows with the semantics described in FR-INV:

- **Preview invitation** by token (FR-INV-001)
- **Accept invitation** by token with email match and idempotency (FR-INV-002)
- **Check membership by email** for batch invite UI (FR-INV-006)

---

## 8. Data requirements (conceptual entities)

La Nonna stores domain data in **Cloud SQL**. Migrations live under `infra/db/`; this section is the **entity checklist** for v1.

| Entity | Purpose | v1 |
|--------|---------|-----|
| `profiles` / app user profile | User display name, avatar, phone, user birth date, country, postal code, terms acceptance, biometric flag | Yes |
| `user_stats` | Gamification aggregates | Yes |
| `baby_profiles` | Baby metadata, dates, gender, birth stats | Yes |
| `baby_memberships` | RBAC owner/follower + relationship | Yes |
| `invitations` | Token invites, roles, expiry | Yes |
| `owner_update_markers` | Content-change marker for cache refresh | **Optional** — client pull-to-refresh / short TTL may suffice |
| `photos` | Media metadata, paths, status | Yes |
| `photo_squishes` | Likes | Yes |
| `photo_comments` | Photo threads | Yes |
| `photo_baby_tags` | Baby tags on photos (FR-GAL-008 v1) | Yes (`019`) |
| `events` | Calendar events | Yes |
| `event_rsvps` | RSVPs | Yes |
| `event_comments` | Event threads | Yes |
| `registry_items` | Wishlist | Yes |
| `registry_purchases` | Single purchase per item | Yes |
| `votes` | Predictions | Yes |
| `name_suggestions` | Name ideas | Yes |
| `name_suggestion_likes` | Likes on names | Yes |
| `notifications` | In-app alerts | Yes |
| `notification_preferences` | Digest frequency + push toggle on `app_users` (weekly digest is push-only) | Yes |
| `device_tokens` | FCM registration per device | Yes |
| `activity_events` | Full-stream activity recap on home (chronological events) | Yes |
| `app_versions` | Force-update config | Yes |
| `system_announcements` | Dismissible home banners (content, schedule, targeting) | Yes |
| `announcement_dismissals` | Per-user dismiss records for announcements | Yes |

Firebase Auth holds identity; link `user_id` to Firebase UID in SQL.

---

## 9. Non-functional requirements

| ID | Requirement |
|----|-------------|
| **NFR-SEC-001** | All API calls use `Authorization: Bearer` Firebase ID token. |
| **NFR-SEC-002** | Enforce Firebase App Check before public beta. |
| **NFR-SEC-003** | GCS access via short-lived signed URLs; upload only to scoped display paths. |
| **NFR-L10N-001** | **English** for all user-visible strings via localization files (no hardcoded copy in widgets). |
| **NFR-OFFLINE-001** | Show offline banner (respect status bar safe area); retain cached thumbs/content; tab load failures use friendly copy + **Try again** (no raw `ClientException` / API host in UI); map network errors via `apiErrorMessage` (#27). |
| **NFR-PERF-001** | Feed and lists use thumbnail URLs; detail uses display asset. |
| **NFR-OBS-001** | Structured logging and monitoring per platform architecture. |
| **NFR-FORCE-001** | Minimum app version per platform from `app_versions`; **hard block** until update (FR-SET-004). |
| **NFR-CI-001** | Maintain E2E scenario coverage (P0 first). **Local gate:** `./scripts/verify-dev-prerequisites.sh` (`flutter analyze`/`test`, API/worker compile); run API `pytest` and mobile tests when touching those layers. **Device:** Maestro flows + `integration_test/` (e.g. `home_summary_load_test.dart`) — manual before release. |
| **NFR-DATA-001** | Support export/deletion flows for compliance and account closure. An **owner** export (`export_version` 2) is a JSON archive of that baby: profile (including shipping address), members, pending invitations, photos, comments, squishes, photo tags, events, RSVPs, registry items and purchases, name suggestions and loves, gender/birthdate predictions, the birth announcement, and recent activity. People are `person_` ids plus **display names** (empty name → “Family member”; missing activity actor → “Someone”). Member emails and Firebase UIDs are omitted. A pending invite keeps the email the owner typed. Anonymous predictions are labeled “Anonymous” and are not linked to a person. Photo tags include only babies the exporting owner is still a member of. Soft-deleted comments are omitted. Photo, thumbnail, and baby-avatar files are **V4 signed GET URLs valid up to 7 days** (the V4 maximum; a documented exception to the 15-minute app URLs in NFR-SEC-003). `export.json` itself is still the short-lived download from the app. Run export again to refresh media URLs. Purchases include the purchaser display name, matching the registry screen. Notifications and export-job rows are operational and are not part of the archive. Account deletion remains FR-SET-005. |

---

## 10. Phasing

### 10.1 v1 (MVP product)

- Core domains FR-AUTH through FR-DEEP on Path B stack.
- Fixed home sections (§6).
- Email invitations + Mailjet.
- Display encode + worker thumbnails.
- English UI copy via localization files.

Engineering status aligns with [development.md](../engineering/development.md) and [operations.md](../engineering/operations.md): §6.2 home hub (slim teasers: upcoming events + recent photos, birth welcome, system announcements, activity paginated route, owner invite/followers) is **implemented on dev**; owner storage meter on My Account (`GET /v1/me/account`); biometric unlock (M-31); branded Hosting/auth/invite HTML; core app chips and onboarding pill/photo-caption UX (Oct 2026). Remaining v1 polish: App Check enforce and device QA for push.

### 10.2 Later

- SMS, contacts picker, QR invites (growth).
- Shareable invite link without email (copy to WhatsApp).
- Apple Sign-In (v1 is email + Google only).
- Dynamic home layout / remote section config (if ever needed).
- Optional realtime feed (still prefer push + refresh).

---

## 11. Resolved product decisions (v1)

| Topic | Decision |
|-------|----------|
| Bottom nav | Home → Gallery → Calendar → Registry → Fun; Profile/Settings via shell menu |
| Notifications | Bell opens full inbox (FR-NOTIF-001) |
| Force update | Hard block below minimum version (FR-SET-004, NFR-FORCE-001) |
| Language | English only; no Spanish (FR-SET-002) |
| System announcements | **Cloud SQL** (`system_announcements` + dismissals) for per-user dismiss and API control |
| Social auth | Email/password + **Google** (FR-AUTH-006); Apple later |
| Fun tab label | Bottom nav and UI copy use **“Fun”** (route `/gamification`) |
| Activity recap | **Full stream** of `activity_events` on home (FR-HOME-007) |
| Complete profile (S04, #391) | Legal: in-app **WebView** + bundled sample HTML (`/legal/terms`, `/legal/privacy`). Country: ISO 3166-1 alpha-2 stored; UI shows full country name list. Phone: any string with max-length validation only. Follower/co-owner: same demographics + terms; **no** relationship pills. Owner: Mother/Father required client-side → `baby_memberships.relationship_label` on create baby. **`profile_complete`:** non-empty `display_name` **and** `terms_accepted_at` (relationship not in API gate). |
| Calendar event visibility (#398, #68) | `starts_at` stored UTC; UI shows **device-local** date/time (`app_date_time.dart` — #4). Calendar tab: **Today** (same local start day, including past start time today) + **Upcoming** (later local days via `upcoming=true`); month lists send the UTC instants of the local month start and next month start (`starts_from` / `starts_before`), so a DST change inside the month is exact. Home teasers stay future-only (`upcoming_only`). After create, lists reload via FAB result + `CalendarRepository` listeners. | Mobile calendar + events API |
| Event cover vs gallery (#315) | Uploading a **new** event cover stores `photos.purpose = event_cover` (not listed in Gallery/home teasers; no `photo_shared` notify). Picking a gallery thumb as cover reuses that gallery row. Orphan `event_cover` rows are removed when the event is deleted or the cover is replaced; deleting a gallery photo clears any event `cover_photo_id` that referenced it. **No backfill** for covers uploaded before this rule. | `040_photo_purpose.sql`; [RCA](../engineering/rca/issue-315-event-cover-gallery.md) |
| Create baby profile photo (#394) | Onboarding create-baby optional photo is a **profile** avatar only by default; checkbox **Also share this photo in the gallery** (default off) runs gallery upload (`/v1/photos/init`). First-moment born photo upload remains gallery-only. | Mobile `OnboardingCreateBabyScreen` |
| Expecting baby names → Fun (#400) | Boy/girl optional names on create-baby (expecting only) become Fun vote options; deduped by name; born lifecycle ignores `profile_name_suggestions`. | `POST /v1/babies` `profile_name_suggestions`; mobile `expectingProfileNameSuggestionsForFun` |
| Default baby profile name (#316) | Expecting + gender unknown: both boy and girl first names → `baby_profiles.name` = creating owner's last name (complete-profile draft or account `display_name` split) when Mother/Father; one name only → that first name; else `NULL`. Mobile-only on create-baby submit; see GitHub #316. | [`resolveOnboardingBabyName`](../../apps/mobile/lib/features/onboarding/presentation/utils/onboarding_baby_helpers.dart), [`resolveBabyNameParentContext`](../../apps/mobile/lib/features/baby/domain/create_baby_submit.dart) |
| Registry Needed row layout (#399) | Owner Needed items: full-width title/description; **Mark as purchased** + edit/delete on second row (avoids crushed text column). | `RegistryNeededRow` |

---

## 12. Appendices

**Scenario IDs** (`E2E-001`, …): La Nonna acceptance test identifiers; mapped to FRs in Appendix D.

### Appendix A — Home section capability mapping

| Capability | Placement | Behavior summary |
|------------|-----------|------------------|
| New baby welcome | Home §1 | Owner; 7 days post-birth |
| Due date countdown | Home §2 | Pre-birth due date |
| Onboarding checklist | Home §3 | Owner onboarding tasks |
| System announcements | Home §4 | Dismissible banners |
| Notifications preview | Home §5 | Preview + link to full inbox if separate |
| Upcoming events | Home §6; Calendar | Teaser + full upcoming screen |
| RSVP tasks | Home §7 | Events needing RSVP |
| Recent photos | Home §8; Gallery | Teaser + recent route |
| Gallery favorites | Home §9; Gallery | Top squished teaser |
| Registry highlights | Registry tab | Featured/open items |
| Recent purchases | Home §11; Registry | Last 15 days |
| Activity recap | Home §12 | Full-stream `activity_events` |
| New followers | Home §13 | Last 30 days; owner |
| Invite status | Home §14 | Pending invites; revoke |
| Storage usage | My Account (`/profile`) | Owner storage meter; FR-PROF-003 |
| Complete profile (onboarding S04) | Onboarding `/onboarding/complete-profile` | Demographics + terms; owner Mother/Father → baby membership label (FR-ONB-003) |
| Registry list | Registry tab body | Full wishlist |
| Name suggestions | Fun tab | List + add flow |
| Prediction votes | Fun tab | Gender + birthdate votes |

### Appendix B — Route inventory

Aligned with `apps/mobile/lib/core/router/app_router.dart` and `features/onboarding/domain/onboarding_routes.dart` (2026-10).

| Route name | Path | Screen |
|-------------------------|------|--------|
| home | `/home` | Home |
| login | `/login` | Legacy redirect → `/onboarding/login` |
| roleSelection | `/role-selection` | Legacy redirect → `/onboarding/owner/carousel` |
| onboardingOwnerCarousel | `/onboarding/owner/carousel` | Owner carousel |
| onboardingSignup | `/onboarding/signup` | Onboarding signup |
| onboardingLogin | `/onboarding/login` | Onboarding login |
| onboardingEmailVerify | `/onboarding/email-verify` | Email verify |
| onboardingCompleteProfile | `/onboarding/complete-profile` | Complete profile (S04) |
| legalTerms | `/legal/terms` | Terms of Service (WebView, bundled HTML) |
| legalPrivacy | `/legal/privacy` | Privacy Policy (WebView, bundled HTML) |
| onboardingOwnerCreateBaby | `/onboarding/owner/create-baby` | Create baby |
| onboardingOwnerFirstMoment | `/onboarding/owner/first-moment` | First moment |
| onboardingOwnerInvite | `/onboarding/owner/invite` | Batch invite (onboarding) |
| onboardingFollowerInvite | `/onboarding/follower/invite` | Follower invite |
| onboardingCoOwnerInvite | `/onboarding/coowner/invite` | Co-owner invite |
| onboardingConfirmRelationship | `/onboarding/follower/confirm-relationship` | Relationship |
| onboardingFollowerCarousel | `/onboarding/follower/carousel` | Follower carousel |
| onboardingCoOwnerWelcome | `/onboarding/coowner/welcome` | Co-owner welcome |
| onboardingWrongEmail | `/onboarding/wrong-email` | Wrong email |
| inviteAccept | `/invite-accept` | Invite accept |
| profile | `/profile` | Account hub (FR-PROF) |
| profileEdit | `/account/edit` | Edit profile |
| settings | `/settings` | Settings hub (notifications, profile edit, help mailto) |
| notificationPreferences | `/account/notification-preferences` | Notification prefs (deep link / entry from settings) |
| accountExport | `/account/export` | Baby data export |
| accountDelete | `/account/delete` | Account delete |
| notificationsInbox | `/notifications/inbox` | Notification inbox |
| homeActivity | `/home/activity` | Paginated activity recap |
| inviteFamily | `/invite-family` | Batch invite from home/account (FR-INV-008) |
| calendar | `/calendar` | Calendar |
| calendarUpcoming | `/calendar/upcoming` | Upcoming events |
| calendarAiSuggestions | `/calendar/ai-suggestions` | AI Suggestions screen (stage/age tabs; static catalog) |
| calendarEvent | `/calendar/event/:id` | Event detail |
| calendarEventCreate | `/calendar/event/create` | Create event |
| calendarEventEdit | `/calendar/event/:id/edit` | Edit event |
| gallery | `/gallery` | Gallery |
| galleryFavorites | `/gallery/favorites` | Favorites |
| galleryRecent | `/gallery/recent` | Recent |
| galleryPhoto | `/gallery/photo/:id` | Photo detail |
| gamification | `/gamification` | Fun / gamification |
| babyCreate | `/baby/create` | Add baby (in-app); shared `CreateBabyScreen` (`CreateBabyMode.inApp`) |
| babyEdit | `/baby/:babyId/edit` | Edit baby |
| babyFollowers | `/baby/:babyId/followers` | Followers management |
| babyAnnouncement | `/baby/:babyId/announcement` | Birth announcement view |
| babyAnnouncementCreate | `/baby/:babyId/announcement/create` | Create announcement |
| registry | `/registry` | Registry |
| registryAiSuggestions | `/registry/ai-suggestions` | Static registry suggestions |
| registryShippingAddress | `/registry/shipping-address` | Structured shipping address form (#408) |
| registryItem | `/registry/item/:id` | Item detail (redirects to edit) |
| registryItemCreate | `/registry/item/create` | Create item |
| registryItemEdit | `/registry/item/:id/edit` | Edit item |

**Deep links:** API payloads may use `/account` or `/notifications`; the client normalizes these to `/profile` and `/notifications/inbox` (`deep_link_navigation.dart`). Notification rows may include `baby_profile_id` for inbox, home preview, and FCM data.

Use static URL builder helpers (e.g. `AppRoutes`, `GalleryRoutes`, `CalendarRoutes`) for navigation and push payloads.

### Appendix C — Entity checklist (one line each)

| Entity | One-line purpose |
|--------|------------------|
| `profiles` | User display profile |
| `user_stats` | Participation aggregates |
| `baby_profiles` | Baby metadata |
| `baby_memberships` | User–baby roles |
| `invitations` | Email/token invites |
| `photos` + squish/comment/tag | Gallery media and social |
| `events` + RSVP/comments | Calendar |
| `registry_items` + `registry_purchases` | Wishlist and claims |
| `votes`, `name_suggestions`, `name_suggestion_likes` | Gamification |
| `notifications`, notification prefs on `app_users`, `device_tokens` | Alerts, digest settings, FCM |
| `activity_events` | Activity recap |
| `app_versions` | Minimum version enforcement |
| `system_announcements`, `announcement_dismissals` | Home banners |

Full v1 scope and optional rows: see §8.

### Appendix D — Acceptance scenario traceability

| Scenario ID | Priority | FR / section coverage | Notes |
|-------------|----------|----------------------|-------|
| E2E-001 | P0 | FR-AUTH-005 | |
| E2E-002 | P0 | FR-AUTH-001, FR-HOME-001 | Home scroll / sections visible |
| E2E-003 | P0 | §5.2 shell | Five tabs |
| E2E-004 | P0 | FR-HOME-002 | Home reload on profile switch |
| E2E-005 | P0 | FR-BABY-001, FR-BABY-003 | |
| E2E-006 | P0 | FR-BABY-004, FR-INV-004 | |
| E2E-007 | P0 | FR-GAL-001–003 | |
| E2E-008 | P0 | FR-GAL-006–007 | |
| E2E-009 | P0 | FR-CAL-002–003 | |
| E2E-010 | P0 | FR-REG-001–003 | |
| E2E-011 | P0 | FR-GAM-001–006 | |
| E2E-012 | P0 | FR-AUTH-004 | |
| E2E-013 | P1 | FR-AUTH-001 | Persisted data |
| E2E-014 | P1 | FR-NOTIF-004 | **No** dark mode or language picker in v1 (FR-SET-002, FR-SET-003) |
| E2E-015 | P1 | FR-HOME-001 (announcements) | |
| E2E-016 | P1 | FR-INV-005 | Invite status section |
| E2E-017 | P1 | FR-GAL-004 | |
| E2E-018 | P1 | FR-CAL-006 | |
| E2E-019 | P1 | FR-REG-005 | |
| E2E-020 | P2 | FR-HOME-004 | |
| E2E-021 | P2 | FR-HOME-003 | + calendar/registry refresh |
| E2E-022 | P2 | §4.1 roles | Follower cannot owner-actions |
| E2E-023 | P1 | FR-REG-007 | Owner mark purchased on needed item |
| E2E-024 | P1 | FR-REG-008 | Registry AI suggestion add + hide-after-add |
| E2E-025 | P1 | FR-CAL-007 | Calendar AI suggestion tabs + hide-after-add |
| E2E-026 | P1 | FR-HOME-001 | Announce arrival (expecting → born) |

---

*End of requirements document.*
