# RCA: Home avatar stale initials (#407)

## Summary

- **A:** After onboarding profile save, the shell avatar shows the **email** initial until force-stop.
- **B:** Signing in as another account without log-out (reachable from #400 carousel) keeps the **previous** user’s initials until baby switch.

## Root cause

- **A:** `OnboardingRepository.updateProfile` updates the server but not `AccountRepository.cachedAccount`. `ensureAccountLoaded()` no-ops when cache exists; the shell uses stale nameless profile → email fallback initials.
- **B:** Addressed by #400 `bindUserScopedSession` + uid-bound `AppSession` status. Avatar cache must also refresh after onboarding save (**A**).

## Fix

| Layer | Change |
|-------|--------|
| `AccountRepository.syncProfileFromServer` | Refetch `/v1/me/account` and publish `profileUpdates` even when cache exists (after onboarding profile save). |
| `OnboardingCompleteProfileScreen` | Calls `syncProfileFromServer` after successful `updateProfile`. |
| `AuthSessionService` | Private `_clearLocalSession()` shared by `signOut` and account-switch listener (same `SessionCleanup.clearLocalUserData()` — no duplicated logic). |

## References

- GitHub #407, #400
- `apps/mobile/lib/features/account/data/account_repository.dart`
- `apps/mobile/lib/features/shell/presentation/shell_top_bar.dart`
