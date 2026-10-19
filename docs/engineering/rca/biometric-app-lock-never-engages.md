# RCA: Biometric app lock never engages on resume or cold start

## Symptom

With **Biometric sign-in & unlock** enabled (`biometric_unlock_enabled`) and a signed-in user past onboarding, the full-screen [`BiometricAppLock`](../../apps/mobile/lib/core/auth/biometric_app_lock.dart) overlay never appears when the app is cold-started or resumed from the background. Manual QA in [pre-beta-qa.md](../pre-beta-qa.md) §6 (kill app → resume → expect lock) fails.

## Root cause (confirmed)

[`BiometricAppLock`](../../apps/mobile/lib/core/auth/biometric_app_lock.dart) is mounted in [`LaNonnaApp`](../../apps/mobile/lib/app.dart) inside `MaterialApp.router`'s `builder`, **above** the `Router` subtree that `go_router` installs. Route location was read with `GoRouter.maybeOf(context)` in `_currentPathOrNull()`. In the `builder` context, `GoRouter` is not an ancestor, so `maybeOf` **always returns `null`**.

Effects:

1. **`_wouldEngageLock()` always returned `false`** — the policy never saw a real path, so resume tracking (`_lockOnResume`) stayed false and `_engageLock()` never ran.
2. **Cold start** — `_evaluateColdStartLock()` saw a null path and scheduled another post-frame callback to call itself, **every frame**, without ever locking (infinite deferral loop).
3. **Sign out from the lock overlay** used `context.go(...)`, which would fail for the same reason if the overlay had ever been shown.

The intended “wait until GoRouter is ready” deferral (see [open-gaps.md](../open-gaps.md) M-31, 2026-10-16) could not succeed from this widget position.

## Fix (architecture)

- **Inject** the app's `GoRouter` instance (owned by [`LaNonnaApp`](../../apps/mobile/lib/app.dart)) into `BiometricAppLock`.
- Read the current location from `router.routerDelegate.currentConfiguration` (not from `BuildContext`).
- Listen to `router.routerDelegate` (and `AppSession` when onboarding status is still unknown) to run **one** cold-start evaluation when route + session + account are settled — no post-frame polling loop.
- Navigate from the lock overlay with `router.go(...)`.

Policy rules ([`biometric_app_lock_policy.dart`](../../apps/mobile/lib/core/auth/biometric_app_lock_policy.dart)) and PR #345 behaviors are unchanged: profile save never engages the lock; onboarding/login paths and signed-out users are excluded; sign-out keeps device enrollment.

## Manual verification (emulator / device)

1. Sign in, complete onboarding, enable **Biometric sign-in & unlock** (one biometric prompt; no immediate second lock prompt).
2. Background the app → return → **Locked** overlay; unlock with biometrics.
3. Kill the app → relaunch → lock on cold start before using the app.
4. From the lock overlay, **Sign out** → owner carousel / login; **Sign in with biometrics** still works.
5. On `/onboarding/login` or with the toggle off, no lock on resume or cold start.
