# RCA: Sign-out never unregisters push device token (#386)

## Summary

Manual **Log out** (and every other sign-out path that only called `AuthRepository.signOut()` after `SessionCleanup`) left rows in `device_tokens` because the client tried `DELETE /v1/me/device-tokens` **after** Firebase had already signed out. `ApiClient` then threw `not_signed_in` and the failure was logged and swallowed.

## Repro (AUTH-007)

1. Sign in; app registers FCM via `PUT /v1/me/device-tokens`.
2. My Account → **Log out**.
3. Cloud Run logs show no `DELETE`; logcat shows `push_token_unregister_failed: not_signed_in` immediately after `FirebaseAuth` sign-out.

## Root cause

`PushNotificationService.start` registered an `authStateChanges` listener that called `_unregisterCurrentToken()` when `user == null`. That event fires only **after** `FirebaseAuth.signOut()`, so `_notificationsRepo.unregisterDeviceToken` ran without a bearer token.

`unregisterOnSignOut()` implemented the correct server call but was **never invoked** from any sign-out path. UI and handlers instead duplicated:

1. `SessionCleanup.clearLocalUserData()`
2. `AuthRepository.signOut()` (Google + Firebase)

`account_screen.dart` even commented that push cleanup was handled by the auth listener — which was incorrect.

## Sign-out paths audited

| Path | Entry | Pre-fix behavior |
|------|--------|------------------|
| Manual log out | `AccountScreen._signOut` | cleanup → Firebase sign-out; no server DELETE |
| Biometric lock overlay | `BiometricAppLock._signOutFromLock` | same |
| Delete account (after API tombstone) | `DeleteAccountScreen._delete` | biometric enrollment clear → cleanup → Firebase |
| Deleted account 401 | `handleUserDeletedSession` | cleanup → Firebase |
| Wrong-account invite switch | `OnboardingWrongEmailScreen` | prefill/resume (PR #369) → cleanup → Firebase |
| Forced sign-out | Same as deleted-account handler (`ApiClient` `onSessionInvalidated` → `user_deleted`) | cleanup → Firebase |

No other production call sites invoked `AuthRepository.signOut()` directly.

## Fix

Introduce **`AuthSessionService.signOut()`** as the single ordered sequence:

1. **Unregister push on the server** while Firebase still has a session — `PushNotificationService.unregisterBeforeSignOut()`, best-effort with a **3s** timeout.
2. **`SessionCleanup.clearLocalUserData()`** — caches, onboarding flags, invite flow (callers that need invite handoff across switch-account, per PR #382, re-apply `InviteFlowState` **after** this step).
3. **`AuthRepository.signOut()`** — Google + Firebase.

`PushNotificationService` auth listener on `user == null` now only performs **local** FCM `deleteToken()` as a fallback (no authenticated DELETE).

`PushNotificationService` is constructed in `bootstrap.dart` and provided to the widget tree so `AuthSessionService` and `LaNonnaApp` share one instance.

## Tests

- `auth_session_service_test.dart` — ordering and push timeout best-effort.
- Existing widget tests updated to provide `AuthSessionService` (delete account, biometric lock, wrong-email switch account).

## Impact if unfixed

Local `deleteToken()` and worker pruning of `UNREGISTERED` FCM responses mitigate mistaken delivery in the common case. Stale `device_tokens` rows still waste fan-out; offline or failed `deleteToken()` on a shared device could surface the previous account’s notifications until the server row is removed.
