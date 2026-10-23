# RCA: Issue #402 — Fun names field keeps text after successful Add

## Summary

After a successful name suggestion on **Fun > Names**, the suggest field still shows the typed name. Tapping **Add** again would submit a duplicate (the API rejects it, but the UX invites the mistake).

## Root cause

Issue #397 fixed stale "Name is required" after submit by replacing `_input.clear()` with `FormState.reset()` only (`names_tab.dart` `_resetSuggestForm`).

`_submit()` turns on deferred validation with `setState(() => _validateSuggestOnInteraction = true)` **before** validation runs. That rebuilds `AppTextFormField` / `TextFormField` while the controller still holds the typed text. Flutter passes `controller.text` as the `FormField` `initialValue` when a controller is attached.

On success, `_resetSuggestForm()` calls `FormState.reset()`. Each `TextFormField.reset()` restores the controller to that `initialValue` — the name just submitted — not to empty. The old code cleared the controller explicitly, which worked for text but re-triggered validation (#397).

Order of operations matters: validation-on rebuild pins a non-empty `initialValue`; `reset()` cannot clear the field without either clearing the controller **after** turning validation off and rebuilding, or resetting on the next frame once `initialValue` reflects an empty controller.

## Duplicate names (server vs client)

**Decision:** duplicate rejection stays in the **API domain** (`domain/fun.suggest_name`), not only in the mobile form.

The domain already calls `find_name_suggestion_case_insensitive` and returns `duplicate_name_suggestion` when the same name exists for that gender. That is the single source of truth for all clients and for retries. The mobile fix is to clear the field after success so users are not nudged to double-submit; the server guard remains the backstop.

## Fix

| Layer | Change |
|-------|--------|
| `core/validation/form_reset_after_submit.dart` | Shared helper to reset a controlled form field after success: disable deferred autovalidate, clear the controller, then `FormState.reset()` on the next frame so `initialValue` matches empty text without firing interaction validation. |
| `names_tab.dart` | Use the helper in `_resetSuggestForm`. |

No other screens use the same submit-and-clear controlled-field pattern today; future add-and-clear forms should call the same helper.

## Test plan

- Mobile `names_tab_validation_reset_test.dart`: assert controller text is empty after successful suggest (existing test; fails on main, passes with fix).
- No API change required for duplicates; existing `test_fun_domain.py` covers case-insensitive duplicate rejection.
