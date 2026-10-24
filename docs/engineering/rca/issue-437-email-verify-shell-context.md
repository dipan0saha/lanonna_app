# RCA: Email verification link handler uses context above MaterialApp (#437)

## Summary

Crashlytics reported a fatal null check in `_LaNonnaAppState._handleEmailVerificationLink` when users opened an email verification App Link. The handler also failed to show snackbars for every outcome (success with “tap continue”, verified-but-signed-out, invalid/expired link).

## Root cause

`_LaNonnaAppState` sits **above** the `MaterialApp.router` it builds in `build()`. The handler used that State’s `context` for `AppLocalizations.of(context)!` and `ScaffoldMessenger.maybeOf(context)`. Localizations and `ScaffoldMessenger` are installed **below** `MaterialApp`, so both lookups returned null (the `!` on localizations threw). Deep-link navigation via `_router.go` still ran, but user-visible feedback was missing.

Push notification deep links already used `appRootNavigatorKey.currentContext` for navigation; snackbars had no shared shell-level messenger key.

## Fix

| Layer | Change |
|-------|--------|
| `app_shell_ui.dart` | Shared `rootScaffoldMessengerKey` on `MaterialApp.router`, plus helpers to read `AppLocalizations` and the messenger from contexts **under** the app shell (`appRootNavigatorKey` / messenger key). |
| `email_verification_link_handler.dart` | Outcome handling (navigation + snackbars) extracted for clarity and testing; `app.dart` delegates here after applying the Firebase link. |
| `app.dart` | Wire `scaffoldMessengerKey`; use shell helpers instead of the root State `context` for UI feedback. |
| `email_verification_link_handler_test.dart` | Widget test per outcome: asserts route and snackbar text. |

## References

- GitHub #437
- `membership_access_handler.dart`, `user_deleted_session_handler.dart` (navigator-key pattern for shell-level work)
