# RCA: Signed-in user with no baby lands on signed-out carousel (#409)

## Summary

A signed-in user with a **complete profile and no baby** (`can_access_main_app: false`, no owner baby, no membership) cold-starts on the **signed-out welcome carousel** and can reach **sign-up** from Skip. Reproduced after leaving a **revoked** invite via Continue, and on every relaunch. Firebase and API sessions remain valid.

## Root cause

Two coupled mistakes:

1. **Router cold start** — `GoRouter` `initialLocation` defaults to `OnboardingRoutes.ownerCarousel` for every launch without an invite deep link. That route is correct only for **signed-out** entry.

2. **`redirectFor` allowlist** — For signed-in users with `!hasOwnerBaby && !hasBabyMembership`, the `allowed` set included `ownerCarousel`, `signup`, and `login`. A signed-in user was therefore **permitted** to stay on public entry screens. The post-#400 fix only sent **main-app** users away from the carousel, not this cohort.

`leaveInvitationFlow()` always `go(ownerCarousel)`, so revoked-invite Continue dropped a signed-in owner onto the same public route.

## Product decision — signed-in, no baby

These users are **authenticated owners without a profile yet** (or former invitees who never joined). They should land on **`/onboarding/owner/create-baby`**: create a baby or, via the existing onboarding chrome and deep links, open an invite. They must **never** see the signed-out carousel or sign-up.

This reuses the established owner create-baby step rather than a new empty-state route, keeping one funnel for “no baby on this account.”

## Fix (extends #400 review)

| Layer | Change |
|-------|--------|
| `AppSession.signedInResumeLocation` | Single function: given loaded status + coordinator + email verified, returns the canonical signed-in destination for every session state (verify email, complete profile, main app → `/home`, active invite handoff, no baby → create baby, owner onboarding resume). |
| `redirectFor` | **Extends** the reviewer rule: any signed-in user on the **welcome carousel** redirects to `signedInResumeLocation` (not only `canAccessMainApp`). Signed-in users on **signup/login** redirect when profile is complete so Skip cannot open sign-up while authenticated. |
| `createAppRouter` | Cold-start `initialLocation` is `/home` when Firebase already has a user (carousel remains the signed-out default). First redirect frame applies the canonical location. |
| `leaveInvitationFlow` | Signed-in → canonical resume; signed-out → carousel. |

## References

- GitHub #409, #400, #388
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
- `apps/mobile/lib/core/router/app_router.dart`
