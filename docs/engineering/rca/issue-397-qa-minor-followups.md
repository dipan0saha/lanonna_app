# RCA: Issue #397 — Baby PATCH 403 parity + Fun names validation reset

## Summary

Two low-severity QA findings from the same pre-prod pass as #392–#394.

### (a) Follower `PATCH /v1/babies/{id}` vs `DELETE`

- **DELETE** (owner-only) uses `require_owner_baby` → `PermissionError` → **403** `forbidden` (see `test_delete_by_non_owner_returns_403`).
- **PATCH** relied on `UPDATE … AND m.role = 'owner'` returning no row, then mapped `None` to **404** `not_found` even when the follower is an active member.

**Convention:** Owner-only mutations use `require_owner_baby` / `assert_owner_membership` and return **403** for non-owners (including followers). **404** remains for non-members (`NOT_MEMBER`) on member-scoped routes; baby profile PATCH/DELETE are owner-gated, not membership-discovery endpoints.

### (b) Fun names suggest form

After a successful suggest or delete, `_input` was cleared but `_validateSuggestOnInteraction` stayed `true`, so `AutovalidateMode.onUserInteraction` immediately showed **Name is required** on the empty field.

**Fix:** After successful mutations, set `_validateSuggestOnInteraction = false` and call `FormState.reset()` (same deferred-validation pattern as account/registry forms).

## Test plan

- API: `test_patch_baby_non_owner_returns_403` in `test_babies_patch.py`.
- Mobile: `names_tab_validation_reset_test.dart` — after submit callback, no validation error on empty field.
