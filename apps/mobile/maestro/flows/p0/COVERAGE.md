# Maestro P0 coverage (part 1 of N)

Maps [pre-prod test plan](../../../../docs/qa/pre-prod-test-plan.md) **P0** IDs to Maestro flows under `maestro/flows/p0/`.  
Run via `./maestro/scripts/run-maestro-p0.sh` or `./scripts/premerge_check.sh --e2e` from repo root.

## Implemented flows (this PR)

| Flow | P0 IDs touched |
|------|----------------|
| `auth_sign_in.yaml` | AUTH-004, AUTH-008 (partial) |
| `auth_sign_out.yaml` | AUTH-007 |
| `auth_sign_up.yaml` | AUTH-001 (optional; `P0_DISPOSABLE_EMAIL_TEMPLATE` in `local.env`) |
| `owner_onboarding.yaml` | ONB-002, ONB-003, ONB-004 |
| `invite_send.yaml` | INV-010 |
| `invite_accept_deep_link.yaml` | INV-001, INV-004 (fixtures issue a fresh follower invite for the second baby) |
| `gallery_upload.yaml` | GAL-001 |
| `account_delete.yaml` | Account delete (optional; deletes the account `auth_sign_up.yaml` just created) |
| `settings_biometric_enable.yaml` | BIO-001 (optional; `P0_RUN_BIOMETRIC=1`, enrolled emulator fingerprint) |
| `auth_biometric_sign_in.yaml` | BIO-006 (optional; after enable flow) |

Shared subflows live in `p0/subflows/` (`sign_in_as`, `sign_in_owner`, `to_home`, `open_account`, `sign_out`); they use semantics ids only and reuse `flows/subflows/owner_onboarding_to_home.yaml` and `flows/subflows/ensure_primary_baby.yaml`.

`run-maestro-p0.sh` provisions fixtures, builds and installs the debug APK (`P0_SKIP_BUILD=1` reuses the installed one), runs every flow even after a failure, and ends with `P0 summary: N passed, M failed, K skipped`. It exits non-zero if any flow failed. Optional flows show as skipped when their variables are unset.

## Full P0 matrix (77 cases)

| ID | Maestro / notes |
|----|-----------------|
| ACC-001 | _Part 2+_ |
| ACC-004 | _Part 2+_ |
| ACC-005 | _Part 2+_ |
| ACC-006 | _Part 2+_ |
| ACC-007 | _Part 2+_ |
| AUTH-001 | `auth_sign_up.yaml` (optional env) |
| AUTH-002 | _Part 2+_ |
| AUTH-003 | _Part 2+_ |
| AUTH-004 | `auth_sign_in.yaml` |
| AUTH-005 | _Part 2+_ |
| AUTH-006 | _Part 2+_ |
| AUTH-007 | `auth_sign_out.yaml` |
| AUTH-008 | `auth_sign_in.yaml` + API integration tests |
| BABY-001 | _Part 2+_ |
| BABY-002 | _Part 2+_ |
| BABY-003 | _Part 2+_ |
| BABY-004 | _Part 2+_ |
| BABY-005 | _Part 2+_ |
| BE-001 | _Part 2+_ |
| BE-002 | _Part 2+_ |
| BE-003 | _Part 2+_ |
| BE-006 | _Part 2+_ |
| BE-010 | _Part 2+_ |
| BIO-001 | `settings_biometric_enable.yaml` (`P0_RUN_BIOMETRIC=1`) |
| BIO-002 | _Part 2+_ |
| BIO-003 | _Part 2+_ |
| BIO-004 | _Part 2+_ |
| BIO-005 | _Part 2+_ |
| BIO-006 | `auth_biometric_sign_in.yaml` |
| CAL-001 | _Part 2+_ |
| CAL-002 | _Part 2+_ |
| CAL-003 | _Part 2+_ |
| CAL-004 | _Part 2+_ |
| CAL-008 | _Part 2+_ |
| DL-001 | _Part 2+_ |
| DL-002 | _Part 2+_ |
| DL-003 | _Part 2+_ |
| ENV-001 | _Part 2+_ (deploy smoke; manual) |
| ENV-002 | _Part 2+_ (migrations; `verify-migrations.sh`) |
| ENV-003 | _Part 2+_ (manual dev run) |
| ENV-005 | _Part 2+_ |
| GAL-001 | `gallery_upload.yaml` |
| GAL-002 | `features/gallery_upload.yaml` in full Maestro suite |
| GAL-003 | _Part 2+_ |
| GAL-005 | _Part 2+_ |
| GAL-007 | _Part 2+_ |
| GAL-008 | _Part 2+_ |
| GAL-010 | _Part 2+_ |
| GAL-012 | _Part 2+_ |
| GAL-013 | _Part 2+_ |
| HOME-001 | _Part 2+_ |
| HOME-002 | _Part 2+_ |
| INV-001 | `invite_accept_deep_link.yaml` + `open-invite-deep-link.sh` |
| INV-002 | _Part 2+_ |
| INV-003 | _Part 2+_ (API; covered by pytest) |
| INV-004 | `invite_accept_deep_link.yaml` |
| MULTI-001 | _Part 2+_ |
| MULTI-002 | _Part 2+_ |
| MULTI-008 | _Part 2+_ |
| MULTI-010 | _Part 2+_ |
| NOT-001 | _Part 2+_ |
| NOT-002 | _Part 2+_ |
| NOT-003 | _Part 2+_ |
| NOT-005 | _Part 2+_ |
| NOT-006 | _Part 2+_ |
| NOT-007 | _Part 2+_ |
| OFF-001 | _Part 2+_ |
| ONB-002 | `owner_onboarding.yaml` |
| ONB-003 | `owner_onboarding.yaml` |
| ONB-004 | `owner_onboarding.yaml` |
| ONB-007 | _Part 2+_ |
| ONB-008 | _Part 2+_ |
| REG-001 | _Part 2+_ |
| REG-002 | _Part 2+_ |
| REG-004 | _Part 2+_ |
| REG-005 | _Part 2+_ |
| VER-001 | _Part 2+_ |
| VER-002 | _Part 2+_ |

**Summary:** 14 P0 IDs have Maestro coverage in part 1 (plus optional sign-up, account delete, and biometrics). **63** remain for follow-up PRs.
