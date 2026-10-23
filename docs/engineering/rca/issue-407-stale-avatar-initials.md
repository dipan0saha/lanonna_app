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
| `AccountRepository.updateProfile` | The one profile write. Gains `acceptTerms` (sent only when true; acceptance is one-way on the server). Its PATCH response already updates the cached account and stored identity. |
| `OnboardingRepository.updateProfile` | **Deleted.** It duplicated the PATCH and bypassed the account cache, which was the root cause of **A**. |
| `OnboardingCompleteProfileScreen` | Saves through `AccountRepository.updateProfile(acceptTerms: true)`; no extra `/v1/me/account` GET. |
| `AuthSessionService` | Private `_clearLocalSession()` shared by `signOut` and account-switch listener (same `SessionCleanup.clearLocalUserData()` — no duplicated logic). |

## Review decision (PR #405)

The first version added `AccountRepository.syncProfileFromServer` (a forced refetch after the onboarding save). It was replaced: it kept two PATCH implementations, cost an extra GET, and could join an `ensureAccountLoaded` request that was already in flight from before the save, which would publish the old name again. Routing the write through the account layer fixes the cause, not the symptom. Tests: `account_identity_test.dart`.

## References

- GitHub #407, #400
- `apps/mobile/lib/features/account/data/account_repository.dart`
- `apps/mobile/lib/features/shell/presentation/shell_top_bar.dart`
