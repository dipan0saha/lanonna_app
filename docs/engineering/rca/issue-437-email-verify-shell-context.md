# RCA: Email verification link handler uses context above MaterialApp (#437)

## Summary

Crashlytics reported a fatal null check in `_LaNonnaAppState._handleEmailVerificationLink` when users opened an email verification App Link. The handler also failed to show snackbars for every outcome (success with “tap continue”, verified-but-signed-out, invalid/expired link).

## Root cause

`_LaNonnaAppState` sits **above** the `MaterialApp.router` it builds in `build()`. The handler used that State’s `context` for `AppLocalizations.of(context)!` and `ScaffoldMessenger.maybeOf(context)`. Localizations and `ScaffoldMessenger` are installed **below** `MaterialApp`, so both lookups returned null (the `!` on localizations threw). Deep-link navigation via `_router.go` still ran, but user-visible feedback was missing.

Push notification deep links already used `appRootNavigatorKey.currentContext` for navigation; snackbars had no shared shell-level messenger key.

## Fix

| Layer | Change |
|-------|--------|
| `app_shell_ui.dart` | Shared `rootScaffoldMessengerKey` on `MaterialApp.router`. `AppShellUi.whenReady` hands the messenger and `AppLocalizations` (read from the messenger's own context, which is below `MaterialApp`) to the caller. A cold-start link can run before the first frame, so it waits for the shell, but at most `maxWaitFrames` frames; it never reschedules indefinitely. |
| `email_verification_link_handler.dart` | Outcome handling (navigation + snackbars) extracted for clarity and testing; `app.dart` delegates here after applying the Firebase link. |
| `app.dart` | Wire `scaffoldMessengerKey`; use shell helpers instead of the root State `context` for UI feedback. |
| `push_notification_service.dart` | Same class of bug, latent: `start()` accepted the root `State` context (above `MaterialApp`) and fell back to `navigateAppDeepLink` with it. `app.dart` always passed `onDeepLink` (root navigator context), so the fallback and the unused `onOpenDeepLink` were dead; both removed and `onDeepLink` is required. |
| `EmailVerificationLinkGate` (handler file, used by `app.dart`) | Found on the emulator: a cold-start link arrives twice, from `readColdStartAppLinkUri` and again on `watchAppLinkUris`. The first apply verified the account; the second failed (code already used) and showed "This verification link has expired or was already used" over Complete your profile. Before this fix that second pass is where the #437 crash fired. The gate lets each `oobCode` through once; a resent email's new code still goes through. |
| `email_verification_link_handler_test.dart` | Widget test per outcome: asserts route and snackbar text, plus a link handled before the shell mounts. |

## References

- GitHub #437
- `membership_access_handler.dart`, `user_deleted_session_handler.dart` (navigator-key pattern for shell-level work)
