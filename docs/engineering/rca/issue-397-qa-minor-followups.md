# RCA: Issue #397 — Baby PATCH 403 parity + Fun names validation reset

## Summary

Two low-severity QA findings from the same pre-prod pass as #392–#394.

### (a) Follower `PATCH /v1/babies/{id}` returned 404

**Root cause:** `DELETE` goes through the domain (`delete_baby_profile` → `require_owner_baby`), so a non-owner gets **403** `forbidden` and an ended membership gets `MEMBERSHIP_ENDED`. `PATCH` skipped the domain on its non-announce path. The router called the owner-scoped repository `UPDATE … AND m.role = 'owner'` directly and turned "no row" into **404** `not_found`, even for an active follower.

**Fix:** a new domain function, `domain/baby_update.update_baby_profile`, next to `baby_delete`. It applies the same `require_owner_baby` gate and treats an owner-scoped `UPDATE` that matches no row as `PermissionError`. The router calls it, and the dead `row is None → 404` branch is gone. The announce path (`announce_arrival`) already raised `PermissionError` for non-owners.

**Compatibility:** the app already sends PATCH only from owner screens. Any 403 goes through the shared error mapping.

### (b) Fun names suggest form showed "Name is required" after a successful suggest

**Root cause:** after a successful suggest, `_input.clear()` ran while `_validateSuggestOnInteraction` was `true`. A controller clear counts as an edit to the `TextFormField`, so `AutovalidateMode.onUserInteraction` validated the now-empty field at once.

**Fix:** `_resetSuggestForm()` calls `FormState.reset()`, which empties the field and forgets the interaction, and turns deferred validation back off. Delete doesn't touch the suggest field, so it no longer resets the user's draft (the first version of this PR did).

## Test plan

- API `test_baby_update_domain.py`:
  - an owner update returns the row;
  - a follower is forbidden and nothing is written;
  - an ended membership raises `MEMBERSHIP_ENDED`;
  - an `UPDATE` that matches no row is forbidden, not a 404.
- API `test_babies_patch.py`: a follower's PATCH through the real router and domain gets 403 `forbidden`, and no update runs.
- Mobile `names_tab_validation_reset_test.dart`: a successful suggest leaves an empty field with no error, and the next empty submit still shows "Name is required". This test fails on main and passes with the fix.
