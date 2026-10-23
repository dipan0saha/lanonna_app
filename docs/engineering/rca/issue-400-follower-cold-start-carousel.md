# RCA: Signed-in follower cold-starts on signed-out welcome carousel (#400)

## Summary

A user who is an active **follower** of one baby and has **created** another baby without finishing owner onboarding (`can_access_main_app: true`, `needs_owner_onboarding: true`) sees the signed-out owner welcome carousel after every cold start, even though the Firebase session and API (`onboarding/status`, `babies`, `home-summary`) are valid.

From that state, signing in as a **different** account without a normal logout leaves the Home top-bar avatar showing the **previous** account's initials until the user switches babies.

## Root cause — carousel (#400)

`GoRouter` cold-starts at `OnboardingRoutes.ownerCarousel` when there is no invite deep link. In `AppSession.redirectFor`, the signed-in branch handles `canAccessMainApp` first:

When **both** `can_access_main_app` and `needs_owner_onboarding` are true, `keepOwnerOnboarding` is true, so the block returns `null` for the owner carousel. That leaves the user on a **public** signed-out route while authenticated.

Later logic that would send `ownerCarousel` to `_onboardingResumePath` never runs because the early `canAccessMainApp` branch already returned.

The intended product rule (comment in `app_session.dart`) is that this user may use **Home** and finish owner onboarding later — not the signed-out carousel or sign-up.

## Root cause — stale avatar initials

`AccountRepository.ensureAccountLoaded()` returns immediately when `cachedAccount` is non-null. `SessionCleanup.clearLocalUserData()` (and thus `clearCachedAccount()`) runs only on explicit logout via `AuthSessionService.signOut()`.

In the #400 state the user is still signed in as account A but sees the carousel. **I already have an account** → sign-in as account B updates Firebase **without** clearing in-memory caches. Account A's profile remains in `cachedAccount`, so the shell avatar keeps A's initials until something forces a refetch (e.g. baby switch triggering unrelated UI refresh). `AccountIdentityStore` is already keyed by uid; the bug is the **in-memory account cache** not reset on uid change.

The same class of bug would affect `BabyListCache`, `SelectedBabyStore`, onboarding coordinator state, etc., if not cleared on account switch.

## Root cause — Registry tab title after baby rename (related gap)

When an owner renames a baby, `HomeRepository.updateBaby` invalidates `BabyListCache` but does **not** update `SelectedBabyStore.selectedBabyName`. The shell title (`shell_top_bar.dart`) reads the persisted name from `SelectedBabyStore`, not the live baby list. Until `resolveSelectedBaby` runs again (baby switch, tab reload, or `notifyBabyContextChanged`), the Registry (and other shell tabs) keep the old title.

This is the same **stale denormalized shell field** pattern as the avatar cache, but the trigger is a baby metadata mutation rather than auth — fixed by syncing the selected baby's display name when `updateBaby` affects the current selection.

## Fix

| Layer | Change |
|-------|--------|
| `AppSession.redirectFor` | When `canAccessMainApp` and `needsOwnerOnboarding`, redirect **signed-out entry routes** (`ownerCarousel`, `login`, `signup`) to `/home`. Owner-onboarding step routes stay reachable. |
| `AuthSessionService.bindUserScopedSession` | On Firebase uid change (B replaces A without going through sign-out), run `SessionCleanup.clearLocalUserData()` and refresh onboarding status + signed-in prefetch — same hygiene as logout, without signing out Firebase. |
| `HomeRepository.updateBaby` | When the patched baby is the selected baby, update `SelectedBabyStore` via `rememberResolvedBaby`. |

## Tests

- `app_session_redirect_test.dart`: both flags true + cold start on owner carousel → `/home`.
- `auth_session_service_test.dart` or dedicated test: uid change clears account cache so the next `identity` matches the new user.
- `home_repository_test.dart`: `updateBaby` refreshes stored shell title for the selected baby.

## References

- GitHub #400, #388 (invite resume), #31, #48
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
- `apps/mobile/lib/core/auth/auth_session_service.dart`
- `apps/mobile/lib/features/home/data/home_repository.dart`
