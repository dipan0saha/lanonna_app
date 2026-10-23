# RCA: Invite flow does not resume after app kill (#388)

## Symptom

After opening a follower/co-owner invite link while signed out, force-stopping the app and relaunching from the launcher (without the link) shows the generic owner intro carousel instead of the invite or sign-up step. The stored `pendingInviteToken` is still on disk (`OnboardingStorage` / `bindInviteFromPreview`).

## Root cause

Cold start without an app link uses `GoRouter` `initialLocation: OnboardingRoutes.ownerCarousel` (`app_router.dart`). For signed-out users, `AppSession.redirectFor` treated `ownerCarousel` as a **public** route and returned `null` before evaluating `pendingInviteToken`, so the pending-invite resume branch never ran on the default cold-start path.

Related QA (same run):

| ID | Symptom | Root cause | Same PR? |
|----|---------|------------|----------|
| (a) | Manage followers delivery label stale after **Resend** | Resend already reloads the list (`_load()`), and the API re-arms the row (`email_delivery_status → pending`) before it returns, so the reload shows the new state. An optimistic local patch would be overwritten by that reload, so none is added. The path where Resend left the label unchanged is (b): a delivered invite failed with "not found" and nothing reloaded. After the worker finishes, the label updates on the next reload (reopen or retry); there is no live delivery event. | Yes — via (b) |
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

- **`AppSession._signedOutPendingInviteRedirect`** runs before the signed-out public allowlist, so a cold start on the owner carousel resumes the invite (`_inviteResumePath()`). Login, sign-up and the invite landing routes are never overridden. A stored step that needs a session (verify email, complete profile, …) resumes on the invite landing instead, so a signed-out user is never sent to a signed-in screen.
- **Stale, revoked or expired token:** the invite landing loads the preview and shows `InviteLandingProblem`. Its Continue (`leaveInvitationFlow`) clears the pending invite and opens the owner carousel, where login and sign-up are available, so there is no loop. Login and sign-up stay reachable directly while the token is pending.
- **Signed-in with a pending token:** unchanged; the signed-in branch still resumes `_inviteResumePath()` before onboarding gates.
- **API resend:** `prepare_invitation_for_resend` returns `prepared` / `already_delivered` / `not_found` in one connection. Already delivered → `409 invite_already_delivered`; missing or no longer pending → 404. The list payload includes `email_sent_at`.
- **Mobile:** `invite_already_delivered` maps through `ApiErrorCode` to `errorInviteAlreadyDelivered`. `InvitationRow.canResendEmail` mirrors the API rule (pending and no `email_sent_at`), so the Resend button is hidden for delivered invites. Older clients without the code get the generic 409 copy, and they rarely see it because they already hide Resend when the status is `sent`.

## Tests

- `app_session_redirect_test.dart`: cold start resumes from the carousel; login and sign-up preserved; sign-up step resumes; a post-sign-up step resumes on the landing; the landing itself is not redirected; with the invite cleared the carousel is reachable.
- `followers_screen_test.dart`: Resend reloads and shows the re-armed label (fake mirrors the API).
- `invitation_row_test.dart`: `email_sent_at` hides Resend.
- `api_error_message_test.dart`: 409 `invite_already_delivered` copy.
- `services/api/tests/test_invitations_resend.py`: route 409/404, and the domain maps each prep outcome (enqueue only when prepared).

## Compatibility

#382 (wrong-account invite handoff) and #387 (sign-out ordering) are merged and do not change `redirectFor` priority; this branch includes them.
