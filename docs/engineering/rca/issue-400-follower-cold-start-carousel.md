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
| `AppSession.redirectFor` | In the `canAccessMainApp` branch, the owner carousel always redirects to `/home`, whether or not owner onboarding is still open. The carousel is the signed-out welcome and the router's cold-start location; it was the only signed-out entry a main-app user could stay on (login and sign-up already behave the same for every main-app user, and stay reachable for invite sign-in). |
| `AppSession` status ownership | `_status` records the uid it was loaded for. `status` / `canAccessMainApp` / routing never use another account's status: after a uid change the next redirect drops it and restores that uid's cached status (or none), and a status fetch that completes after the uid changed is discarded. `SessionCleanup` did not cover this in-memory status at all, so the previous account's status could route the next account until its own fetch finished. |
| `AuthSessionService.bindUserScopedSession` | On a Firebase uid change without sign-out (A → B), runs the same `SessionCleanup.clearLocalUserData()` as `signOut` (no server call: A's ID token is gone; the FCM token is re-registered to B by `PushNotificationService`, and the API reassigns it on conflict), then one callback for B's startup reads. Sign-in from signed out does nothing here, because `signOut` already cleaned up. The bound uid is updated before any await, so back-to-back auth events are compared with the right previous uid. |
| `bootstrap.dart` | One `prefetchSignedInSession` closure (the existing `startSignedInStartupPrefetch`, which already refreshes onboarding status) serves both the cold start and the account switch. |
| `HomeRepository.updateBaby` | When the patched baby is the selected baby, update `SelectedBabyStore` via `rememberResolvedBaby`. |

## Review decisions

- **Why the redirect is the source for the carousel.** `GoRouter` starts at the carousel only as a placeholder; `redirectFor` is the single authority for where a signed-in user may stand. The gap was that one branch let `needs_owner_onboarding` keep a main-app user on a signed-out screen. The fix is that one rule, not an allowlist of signed-out screens. An earlier version also sent login and sign-up to `/home` for this user only, which made the both-flags user behave differently from every other main-app user.
- **Cleanup coverage.** `SessionCleanup` clears the invite flow, onboarding coordinator (progress, pending invite, created baby, cached statuses), baby list and home summaries, account, unread count and inbox, gallery, calendar, the selected baby and signed image caches. Registry, Fun, announcement and invitations repositories hold no user cache. `BabyListCache` and `AccountIdentityStore` are already keyed by uid. Biometric enrollment and push tokens follow auth state on their own. The one uncovered user-scoped state was `AppSession`'s in-memory status, fixed by uid ownership above.
- **Known limit.** The switch cleanup runs from the auth event, in parallel with the sign-in screen's own `refreshFromApi`. Status is safe (uid-owned). Other caches are cleared locally in milliseconds, before B's network reads usually return; the switch prefetch then reloads them for B.
- **Rename and the shell title (#400 related).** `SelectedBabyStore` keeps the selected baby's name so the shell title survives an offline cold start; reading the title from the live baby list instead would lose it offline. `HomeRepository` is the only writer of that store from server responses (`resolveSelectedBaby`), and `updateBaby` gets the renamed baby back from the server, so syncing there is the right layer. A rename on another device still shows on the next `resolveSelectedBaby`.

## Tests

- `app_session_redirect_test.dart`: both flags true or main-app only, on the carousel → `/home`; another uid's status is not used for routing.
- `auth_session_service_test.dart`: A → B runs local cleanup then the prefetch, with no server call or Firebase sign-out; sign-out then sign-in is not treated as a switch.
- `home_repository_test.dart`: `updateBaby` refreshes the stored shell title for the selected baby.

## References

- GitHub #400, #388 (invite resume), #31, #48
- `apps/mobile/lib/features/onboarding/presentation/app_session.dart`
- `apps/mobile/lib/core/auth/auth_session_service.dart`
- `apps/mobile/lib/features/home/data/home_repository.dart`
