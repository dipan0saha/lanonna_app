# RCA: Biometric toggle ON but no sign-in CTA after another account used the device (#375)

## Symptom

Account A enables **Biometric sign-in & unlock**, logs out, then account B signs in and out on the same device. Account A signs back in with email/password.

- **Settings** shows the biometric toggle **ON**.
- **App lock** still engages on cold start / resume.
- After A logs out again, **Sign in with biometrics** is missing on the login screen until the user turns the toggle off and on (re-enroll).

Severity: the feature partially works (lock) while the UI claims full enrollment; post-logout sign-in is silently broken.

## Per-account model (this install)

Biometric sign-in & unlock combines two layers. Only one **hardware signing key** exists on the device (`BiometricSignInService.keyAlias`); at most one account can hold the local enrollment slot.

| Layer | Scope | What it stores |
| --- | --- | --- |
| **Server profile** | Per Firebase user (account) | `biometric_unlock_enabled` on `/v1/profile`. Turning the setting **off** revokes **all** device credentials for that account. Turning **on** sets the flag; credentials are per install via `POST /v1/me/biometric-credentials` and `device_id`. |
| **Local enrollment** | Per install, single slot | `BiometricSignInStore`: `credential_id`, `firebase_uid`, display name. Private key in Keystore / Secure Enclave. Survives **Log out** for the **same** account. |
| **App lock prompt** | Per install while signed in | `local_auth` only; does not use the signing key. |

**Which account owns the stored credential?** The account whose `firebase_uid` is in `BiometricSignInStore`. If the store is empty, no account owns a usable signing key on this install.

**Another account signs in (any route):** [`BiometricSignInService.bindAuthState`](../../apps/mobile/lib/core/auth/biometric_sign_in_service.dart) calls `clearLocalEnrollment()` when the new Firebase `uid` differs from the stored `firebase_uid`. That deletes the key and clears the store. The **previous account's server flag and server-side credentials are unchanged** (this device is not authenticated as that user). Biometric sign-in after logout for the previous account cannot work until they enroll again on this install.

**Toggle for a signed-in user:** Must reflect **on-device activation** for the **current** session, not the server flag alone:

```text
activeOnDevice =
  profile.biometric_unlock_enabled
  AND localEnrollment != null
  AND localEnrollment.firebaseUid == currentUser.uid
```

When `biometric_unlock_enabled` is true but local enrollment is missing or belongs to another uid (cleared when someone else signed in), `activeOnDevice` is **false**. The toggle shows **off**; the login screen correctly hides **Sign in with biometrics**; app lock must not engage until the user turns the setting on again (re-enroll + flag already true or set during enroll flow).

**Other account's credential on the server:** Unchanged when B signs in; only B's session could revoke B's keys. A's orphaned credential for this `device_id` may remain until A re-enrolls (replaces this install's key) or turns the setting off (revokes all keys for A).

Design reference: [biometric-signin-after-logout.md](./biometric-signin-after-logout.md) (logout keeps enrollment; another account clears local only).

## Root cause

1. **`clearLocalEnrollment()` on account switch** (intended) removed the signing key and store when B signed in, while A's `biometric_unlock_enabled` stayed true on the server.
2. **Settings** ([`biometric_unlock_settings_tile.dart`](../../apps/mobile/lib/features/settings/presentation/biometric_unlock_settings_tile.dart)) bound the switch only to `account.biometricUnlockEnabled` (server).
3. **Login** ([`onboarding_login_screen.dart`](../../apps/mobile/lib/features/onboarding/presentation/screens/onboarding_login_screen.dart)) showed the CTA only when `BiometricSignInService.enrollment != null` (local).
4. **App lock** ([`biometric_app_lock.dart`](../../apps/mobile/lib/core/auth/biometric_app_lock.dart)) used the server flag only, so lock still engaged for A after password sign-in despite no local signing enrollment.

There was no single source of truth for “biometric sign-in & unlock is fully active **on this device** for the signed-in account.”

## Fix

- Introduce [`biometric_unlock_state.dart`](../../apps/mobile/lib/core/auth/biometric_unlock_state.dart) with `biometricUnlockActiveOnDevice` as the shared predicate.
- **Settings toggle**, **app lock policy input**, and any signed-in UI use that predicate via `BiometricSignInService.isUnlockActiveForSignedInUser`.
- No server PATCH on account switch or on drift detection: other devices keep their enrollment; this install shows off until the user re-enables (enroll path already handles `device_id` replacement).

## Manual verification (#375)

1. Account A: enable biometrics → log out → **Sign in with biometrics** works.
2. Sign in as B → log out.
3. Sign in as A with password → Settings toggle **off**; cold start / resume **no** app lock until re-enabled.
4. Log out → no biometric CTA (until A re-enrolls).
5. A: turn setting on → one prompt → log out → biometric CTA returns.
