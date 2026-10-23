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

**`AuthSessionService`** is the only place a session ends on this device. It has two entry points with one ordering:

**`signOut()`** for a normal logout (account screen, app-lock overlay, wrong-account Switch account):

1. **Unregister push on the server** while Firebase still has a session: `PushNotificationService.unregisterFromServer()`. This is best-effort and bounded by a **3 s** timeout, so a slow or offline network never holds sign-out longer than that (offline fails immediately in `ApiClient`).
2. **`SessionCleanup.clearLocalUserData()`** clears caches, onboarding flags and invite flow. Switch account re-applies its `InviteFlowState` handoff **after** this step (#369).
3. **`AuthRepository.signOut()`** signs out of Google and Firebase.

The biometric sign-in enrollment is **kept**: biometric sign-in survives logout. It is dropped only when another account signs in (`BiometricSignInService.bindAuthState`, #375), when the setting is turned off, or when the account is deleted.

**`signOutDeletedAccount()`** for delete account and the API `user_deleted` 401 handler:

- **No** server unregister. Account deletion already removed the user's `device_tokens` and biometric credentials (#365). An authenticated DELETE would fail with `user_deleted`, which re-enters `handleUserDeletedSession` (the delete-account flow would then sign out twice and show the "account deleted" alert).
- Clears this install's biometric enrollment **only if it belongs to the deleted account**, then runs steps 2 and 3.

The `PushNotificationService` auth listener on `user == null` performs the **local** FCM `deleteToken()` for every path (no authenticated call). `PushNotificationService` is constructed in `bootstrap.dart` and provided to the widget tree, so `AuthSessionService` and `LaNonnaApp` share one instance.

## Tests

- `auth_session_service_test.dart`: order (unregister → local cleanup → Firebase), a slow unregister abandoned at the timeout, enrollment kept on logout, and deleted-account sign-out making no server call while clearing only that account's enrollment.
- `delete_account_screen_test.dart`: delete goes through `signOutDeletedAccount` (enrollment cleared once, single sign-out).
- Existing widget tests provide `AuthSessionService` (biometric lock, wrong-email switch account).

## Impact if unfixed

Local `deleteToken()` and worker pruning of `UNREGISTERED` FCM responses mitigate mistaken delivery in the common case. Stale `device_tokens` rows still waste fan-out; offline or failed `deleteToken()` on a shared device could surface the previous account’s notifications until the server row is removed.
