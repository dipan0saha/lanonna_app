# RCA: Signed-in user with no baby lands on signed-out carousel (#409)

## Summary

A signed-in user with a **complete profile and no baby** (`can_access_main_app: false`, no owner baby, no membership) cold-starts on the **signed-out welcome carousel** and can reach **sign-up** from Skip. Reproduced after leaving a **revoked** invite via Continue, and on every relaunch. Firebase and API sessions remain valid.

## Root cause

Two coupled mistakes:

1. **Router cold start** — `GoRouter` `initialLocation` defaults to `OnboardingRoutes.ownerCarousel` for every launch without an invite deep link. That route is correct only for **signed-out** entry.

2. **`redirectFor` allowlist** — For signed-in users with `!hasOwnerBaby && !hasBabyMembership`, the `allowed` set included `ownerCarousel`, `signup`, and `login`. A signed-in user was therefore **permitted** to stay on public entry screens. The post-#400 fix only sent **main-app** users away from the carousel, not this cohort.

`leaveInvitationFlow()` always `go(ownerCarousel)`, so revoked-invite Continue dropped a signed-in owner onto the same public route.

## Product decision — signed-in, no baby

These users are signed in with a complete profile and **no baby**: a new owner, a follower who left or was removed from their only baby, or someone whose invite was revoked or expired before they joined. They land on **`/onboarding/owner/create-baby`** and must **never** see the signed-out carousel or sign-up.

**Waiting for, or holding, an invite.** Joining is only possible through the invite link (there is no "my pending invites" API, and the link carries the token). The first version relied on "the existing onboarding chrome and deep links", but the create-baby step said nothing about invites, so a former follower had no way to know what to do. The step now shows a shared `OnboardingNoteCard` ("Joining a family's baby instead?": open the invite link from their email on this phone; if it was revoked or expired, ask for a new one), from ARB strings. It is shown only on the onboarding create-baby step (not the in-app Add Baby screen, and not when revising an owner baby).

**Why not a separate empty state:** an empty-state route would duplicate the create-baby funnel and still need the same two choices (create, or open a link). One screen with the note keeps a single destination for "no baby on this account" in `signedInResumeLocation`, and opening an invite link from there already works (`inviteAccept` is never redirected away).

## Fix (extends #400 review)

| Layer | Change |
|-------|--------|
| `AppSession.signedInResumeLocation` | Single function: given loaded status + coordinator + email verified, returns the canonical signed-in destination for every session state (verify email, complete profile, main app → `/home`, active invite handoff, no baby → create baby, owner onboarding resume). |
| `redirectFor` | **Extends** the reviewer rule: any signed-in user on the **welcome carousel** redirects to `signedInResumeLocation` (not only `canAccessMainApp`). Signed-in users on **signup/login** redirect when profile is complete so Skip cannot open sign-up while authenticated. |
| `createAppRouter` | Cold-start `initialLocation` is `/home` when Firebase already has a user (carousel remains the signed-out default). |
| `leaveInvitationFlow` | Clears every invite handoff, then signed-in → canonical resume; signed-out → carousel. |
| `CreateBabyScreen` (onboarding) | Join-by-invite note (`OnboardingNoteCard`, ARB strings). |

## Cold start: no Home flash, no Home reads (PR #405 review)

- The GoRouter redirect runs before the first build and `redirectFor` restores the uid's cached status synchronously, so a signed-in launch at `/home` for a user who belongs elsewhere resolves to that destination before anything is built. Widget test: *signed-in cold start at /home never builds Home for a no-baby user*.
- **No status at all** (first launch after install, nothing cached, fetch in flight) used to fall through to *complete profile*: a guessed step that flashed for main-app users. `signedInResumeLocation` now returns the session screen (`/session-offline`: spinner while loading, offline retry when the fetch failed, starts a fetch if none is running), which redirect leaves for the canonical destination once a status exists.
- The startup prefetch no longer starts the speculative Home summary when the cached status says the session cannot open Home (e.g. a stale selected baby id after leaving the only baby).
- A redirect to the location the user is already on returns null (a self-redirect is a GoRouter loop).

## Routing table (single decision: `AppSession.signedInResumeLocation`)

| Signed-in state | Destination | Test (`app_session_redirect_test.dart`, group *signed-in routing table*) |
|---|---|---|
| Email not verified | email verify | email not verified |
| No status yet / fetch failed with nothing cached | session screen | no status yet; status fetch failed |
| Profile incomplete | complete profile | profile incomplete |
| May use the main app (with or without owner onboarding open) | `/home` (sign-in screens stay reachable to accept another invite) | may use the main app; main app with owner onboarding still open |
| Invite handoff (token or preview) to resume | invite step / landing | invite handoff to resume |
| Stale invite path, no handoff | create baby (landings redirect too) | stale invite path without a handoff |
| No owned baby and no membership | create baby | no owned baby and no membership |
| Owner onboarding open, no main app | owner resume step | owner onboarding open without main app |

Each row checks the resume location and the redirect from the carousel, `/home`, sign-up and login. Also covered: leaving the session screen once a status loads, a live `inviteAccept` link is never redirected, and no self-redirect.

Dead branches removed with the rule: the carousel, sign-up and login entries in the owner allowlists, the duplicated carousel cases, and the separate session-screen exit (now the canonical destination).

## References

- GitHub #409, #400, #388
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
- `apps/mobile/lib/core/router/app_router.dart`
