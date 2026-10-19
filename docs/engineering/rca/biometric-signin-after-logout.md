# RCA: Biometric sign-in after logout (M-31 extension)

## Symptom

Owners could enable biometrics in Settings but saw no biometric option on the sign-in screen after **Log out**.

## Root cause (pre-fix)

M-31 shipped **biometric unlock** only: `biometric_unlock_enabled` on the profile and `BiometricAppLock` while a **Firebase session still existed**. Log out called `AuthRepository.signOut()`, which cleared the Firebase session. There was no device credential, no challenge–response API, and no login-screen CTA. Prototype copy (“Biometric Login”) diverged from product/engineering docs (“not a login replacement”).

## Chosen design (single setting)

**One toggle** — "Biometric sign-in & unlock" (`biometric_unlock_enabled`):

| When | Behavior |
|------|----------|
| Turned on (signed in) | `biometric_signature` creates a hardware-backed P-256 key (Android Keystore / iOS Secure Enclave; biometric required for every use; invalidated when biometrics are added or removed). That key-creation prompt is the biometric check. The public key (SPKI PEM) is registered with `POST /v1/me/biometric-credentials` (`algorithm: ecdsa_p256_sha256`, random per-install `device_id`; re-enrolling replaces this install's key for the account), then `PATCH /v1/profile`. The app keeps only `credential_id`, the Firebase uid and the first name in `SharedPreferences`; no token, password or email. |
| While signed in | `BiometricAppLock` prompts on cold start / resume. A profile save never engages the lock (so turning the setting on, or the first save after signing in, does not prompt again); it only releases it when the setting goes off. |
| **Log out** (Account or lock overlay) | Firebase session and in-memory data cleared; enrollment and key kept; the login screen shows **Sign in with biometrics** ("Continue as <first name>"). |
| Sign-in | `POST /v1/auth/biometric/challenge` → the key signs the nonce's UTF-8 bytes (`SHA256withECDSA` / `ecdsaSignatureMessageX962SHA256`: DER, standard Base64) → `POST /v1/auth/biometric/sign-in` → API verifies → Firebase **custom token** → `signInWithCustomToken` → `navigateAfterOnboardingAuth`. |

**Removed** (server + local):

- Toggle off — `PATCH /v1/profile` with `false` revokes every device key of the account; the app deletes its key.
- Account deletion — `soft_delete_account_rows` revokes in the same transaction; the app deletes its key.
- Any other account signing in on this device (email, Google, sign-up, invite) — `BiometricSignInService.bindAuthState` drops the local enrollment and key.
- A key that can never work again — invalidated by a biometric change, or rejected by the API (`biometric_credential_invalid`) — is dropped on the failed attempt and the CTA disappears.

## API contract

| Route | Auth | Result |
|-------|------|--------|
| `POST /v1/me/biometric-credentials` | ID token + App Check | `{id, created_at}`; 400 unless the key is EC P-256 |
| `POST /v1/auth/biometric/challenge` | App Check, rate limited | `{challenge_id, nonce, expires_at}` (32-byte nonce, 2-minute TTL; issuing one deletes the credential's previous challenge) |
| `POST /v1/auth/biometric/sign-in` | App Check, rate limited | `{custom_token}` |

The challenge is consumed by one `DELETE … RETURNING` before anything else is checked, so a nonce is verified at most once, pass or fail, even under concurrent requests. Every reason a credential cannot sign in (unknown, revoked, tombstoned account, bad signature, Firebase user missing or disabled, `tokens_valid_after` later than enrollment) returns the same `401 biometric_credential_invalid`; the account-state cases also revoke the credential. An expired or used challenge is `410 biometric_challenge_expired` (retry).

**Plugin:** `biometric_signature` ^13.2.0 (Keystore / Secure Enclave challenge–response, enrollment invalidation). Requires `FlutterFragmentActivity` and `USE_BIOMETRIC` (both present).

## Threat model

| Risk | Mitigation |
|------|------------|
| Stolen device without the owner's biometric | Key use requires a biometric every time; no reusable secret on the device. |
| Replay of a signed nonce | Single-use, credential-bound, 2-minute challenge deleted atomically on first use. |
| Credential guessing / stuffing | 122-bit random credential ids; per-IP rate limit on `/v1/auth/biometric/*`; App Check; one opaque error code. |
| Revoked / deleted / disabled user, password reset | Tombstone check in SQL; Firebase `disabled` and `tokens_valid_after` vs credential `created_at`. |
| Wrong account on a shared device | Another account's sign-in clears the local enrollment; toggle-off revokes server-side. |
| Biometric enrollment change | Key invalidated by the OS; the app drops the enrollment; user turns the setting on again. |

## IAM / deploy

`create_custom_token` on Cloud Run signs through the IAM Credentials API as the API service account, which needs `iam.serviceAccounts.signBlob` on itself. That is the existing `api_self_token_creator` binding (`roles/iam.serviceAccountTokenCreator`, also used for GCS signed URLs; `run_iam.tf`), with `roles/firebaseauth.admin` for `get_user`. No new IAM. **Deploy order:** migration **`041_biometric_credentials`** → **API** (`services/api/scripts/deploy.sh`) → mobile build. Worker unchanged.

## Manual verification

- Turn the setting on → one biometric prompt, no extra lock prompt.
- Background the app → lock overlay → unlock.
- Log out → login shows **Sign in with biometrics** → finger → Home.
- Wrong finger → the system prompt says not recognized and allows a retry; cancel leaves the login screen unchanged.
- Turn the setting off → Log out → no CTA.
- Add a fingerprint (Android) → biometric sign-in fails once with the "changed" message and the CTA goes away until re-enabled.
- Sign in as another account → the previous account's CTA is gone.
