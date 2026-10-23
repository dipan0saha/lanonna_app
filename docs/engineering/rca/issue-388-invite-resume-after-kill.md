# RCA: Invite flow does not resume after app kill (#388)

## Symptom

After opening a follower/co-owner invite link while signed out, force-stopping the app and relaunching from the launcher (without the link) shows the generic owner intro carousel instead of the invite or sign-up step. The stored `pendingInviteToken` is still on disk (`OnboardingStorage` / `bindInviteFromPreview`).

## Root cause

Cold start without an app link uses `GoRouter` `initialLocation: OnboardingRoutes.ownerCarousel` (`app_router.dart`). For signed-out users, `AppSession.redirectFor` treated `ownerCarousel` as a **public** route and returned `null` before evaluating `pendingInviteToken`, so the pending-invite resume branch never ran on the default cold-start path.

Related QA (same run):

| ID | Symptom | Root cause | Same PR? |
|----|---------|------------|----------|
| (a) | Manage followers delivery label stale after **Resend** until screen reopen | Resend called `_load()` but the list subtitle only changed after a full navigation cycle; no optimistic patch when the API arms a new send (`email_delivery_status → pending`) | Yes — invite management UX |
| (b) | **Resend** on an already-delivered invite shows “Invitation not found” | API `prepare_invitation_for_resend` only updates rows with `email_sent_at IS NULL`; a delivered row returned `None` and domain raised generic `LookupError`. Mobile `canResendEmail` did not consider `email_sent_at` | Yes — same resend contract |

## Redirect priority (central router)

Order enforced across cold start, warm deep links, signed-out, and signed-in. **Force update** and **auth** sit outside `redirectFor`; everything else is in `AppSession.redirectFor` (invoked from `createAppRouter`).

1. **Force update** — `AppVersionGate` / `AppVersionService` blocks the tree before `GoRouter` when the installed build is below API minimum (FR-SET-004).
2. **Auth normalization** — path aliases (`/login` → login, role selection → owner carousel); legal routes always allowed.
3. **Pending invite** — when `OnboardingCoordinator.pendingInviteToken` is set, resume the invite funnel (`_inviteResumePath`: invite landing, sign-up, email verify, etc.). **Exceptions:** explicit `login` and `signup` routes are not overridden; invite landing paths already on screen are left alone.
4. **Onboarding / intro** — signed-out public routes (owner carousel, auth screens, invite landing); signed-in onboarding gates (email verify, complete profile, owner steps, offline session) per server `OnboardingStatus`.
5. **Main app** — `can_access_main_app` → `/home`; otherwise resume owner or invite steps from status + coordinator.

Deep links that include `token=` still enter via `/invite-accept` (bootstrap `initialInviteLocation` or warm `app_links`); step (3) covers relaunch **without** a link.

## Fix

- **`AppSession._signedOutPendingInviteRedirect`** — evaluate pending invite before the signed-out public-route allowlist; cold start on owner carousel redirects to `_inviteResumePath()`.
- **Manage followers resend** — optimistic `email_delivery_status: pending` after a successful resend; list payload includes `email_sent_at`; `canResendEmail` requires no prior send.
- **API resend** — `invite_already_delivered` (409) when the pending row already has `email_sent_at`; true missing rows stay 404.

## Tests

- `apps/mobile/test/app_session_redirect_test.dart` — signed-out cold start, login/sign-up preserved, signup step resume.
- `apps/mobile/test/followers_screen_test.dart` — resend patches delivery label (widget).
- `services/api/tests/test_invitations_resend.py` — 409 for already delivered.

## Compatibility

Open PRs #382 (wrong-account invite handoff) and #387 (sign-out ordering) do not change `redirectFor` priority; rebase this branch on `main` as they merge.
