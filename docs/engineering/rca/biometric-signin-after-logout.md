# RCA: Biometric sign-in after logout (M-31 extension)

## Symptom

Owners could enable biometrics in Settings but saw no biometric option on the sign-in screen after **Log out**.

## Root cause (pre-fix)

M-31 shipped **biometric unlock** only: `biometric_unlock_enabled` on the profile and `BiometricAppLock` while a **Firebase session still existed**. Log out called `AuthRepository.signOut()`, which cleared the Firebase session. There was no device credential, no challenge–response API, and no login-screen CTA. Prototype copy (“Biometric Login”) diverged from product/engineering docs (“not a login replacement”).

## Chosen design (single setting)

**One toggle** — “Biometric sign-in & unlock” (`biometric_unlock_enabled`):

| When enabled (signed in) | Device generates a hardware-backed key (`biometric_signature`, ECDSA P-256, invalidated on biometric enrollment change). Public key registered via `POST /v1/me/biometric-credentials`. Local marker: `credential_id` + masked account hint only (no tokens/passwords). |
| While signed in | `BiometricAppLock` unchanged: re-prompt biometrics on cold start / resume. |
| After **Log out** (Account or lock overlay) | Firebase session cleared; **device credential kept**; login screen shows **Sign in with biometrics** when a local enrollment exists. |
| Sign-in | `POST /v1/auth/biometric/challenge` → biometric signs nonce → `POST /v1/auth/biometric/sign-in` → API verifies signature → Firebase **custom token** → `signInWithCustomToken` → existing `navigateAfterOnboardingAuth`. |

**Lock overlay “Sign out”** — Same as Account **Log out**: ends the Firebase session and clears in-memory app data via `SessionCleanup`, but **does not** revoke the device credential or delete the Keystore key, so biometric sign-in remains available on the login screen.

**Revoke device credential** (server + local key delete):

- Toggle off
- Account deletion
- Interactive sign-in as a **different** Firebase user (email/Google) on this device
- Successful biometric sign-in after server rejects credential (revoked / password rotation via `tokens_valid_after`)

**Plugin:** `biometric_signature` ^13.2.0 — maintained, documents Android Keystore / iOS Secure Enclave challenge–response, enrollment invalidation, and backend verification; avoids a custom platform channel.

## Threat model

| Risk | Mitigation |
|------|------------|
| Stolen custom token | Short-lived; obtained only after signature + App Check; TLS. |
| Replay of signed nonce | Single-use challenge, short TTL, server-stored `used_at`. |
| Credential stuffing | Rate limit on `/v1/auth/biometric/*`; audit log per attempt. |
| Revoked / deleted user | Check `app_users.deleted_at`; credential `revoked_at`; Firebase `tokens_valid_after` vs credential `created_at`. |
| Wrong user on shared device | New interactive sign-in clears local enrollment and deletes keys; server revokes on toggle off / delete. |
| Biometric enrollment change | Keystore/Secure Enclave invalidates key; sign-in fails until user re-enables setting (re-enroll). |
| App Check bypass | Challenge/sign-in require `X-Firebase-AppCheck` (same as other sensitive routes). |

## IAM / deploy

API runtime SA already has `roles/firebaseauth.admin` (custom tokens). No new role required. **Deploy:** migration `041` → API → mobile build. Re-run `./scripts/apply-dev-run-iam.sh` only if IAM scripts change (this change documents parity; TF already grants `firebaseauth.admin`).

## Manual verification

- Enable toggle → background app → lock overlay → unlock.
- Log out → login shows biometric CTA → sign-in succeeds.
- Toggle off → CTA gone; server credential revoked.
- Add fingerprint (Android) → prior sign-in fails until re-enable.
- Sign in as another user → prior user’s biometric CTA cleared.
