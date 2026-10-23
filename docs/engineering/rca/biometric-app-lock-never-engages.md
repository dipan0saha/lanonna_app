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
- Listen to `router.routerDelegate`, `AppSession` and `AccountRepository.profileUpdates` to run **one** cold-start evaluation, no post-frame polling loop. A signed-in launch settles when onboarding status is `loaded` and either the user has no main-app access yet (no lock; finishing onboarding later never pops a cold-start lock) or the profile is known and the route has left the onboarding paths. An offline launch without a profile keeps the evaluation pending and locks when the profile first loads, instead of silently skipping the lock. A listener that fires during a build (the initial route parse) applies the lock right after that frame.
- Navigate from the lock overlay with `router.go(...)`.

Review follow-ups (same PR):

- **Resume lock arms only on `AppLifecycleState.paused`.** `inactive` is a focus loss (notification shade, permission dialog, the biometric prompt itself), and `hidden` is also passed on the way back to the foreground. Arming on those re-locked the app right after a successful unlock, or locked it when the user pulled down the shade. The state is not re-armed while the overlay is up or a prompt is in progress.
- Removed the unused `context.watch<AppSession>()` rebuild; router listener moves on `didUpdateWidget`.

Policy rules ([`biometric_app_lock_policy.dart`](../../apps/mobile/lib/core/auth/biometric_app_lock_policy.dart)) and PR #345 behaviors are unchanged: profile save never engages the lock; onboarding/login paths and signed-out users are excluded; a fresh sign-in (password, Google or biometric) never locks; sign-out keeps device enrollment.

`routerDelegate.currentConfiguration.uri` is the full matched location, including nested `ShellRoute` / `StatefulShellRoute` paths. For an imperatively pushed route it is still the base location; the onboarding paths the policy excludes are reached with `go`, so that difference does not change the result.

## Manual verification (emulator / device)

1. Sign in, complete onboarding, enable **Biometric sign-in & unlock** (one biometric prompt; no immediate second lock prompt).
2. Background the app → return → **Locked** overlay; unlock with biometrics.
3. Kill the app → relaunch → lock on cold start before using the app.
4. From the lock overlay, **Sign out** → owner carousel / login; **Sign in with biometrics** still works.
5. On `/onboarding/login` or with the toggle off, no lock on resume or cold start.

## Related code (resume grace period, 2026-10)

**Symptom:** With the lock working again (PR #346), every return from background triggered the overlay—even a quick app switch under a few seconds—because resume locking armed on `AppLifecycleState.paused` and engaged unconditionally on `resumed`.

**Layers involved:**

| Layer | Role |
| --- | --- |
| [`biometric_app_lock.dart`](../../apps/mobile/lib/core/auth/biometric_app_lock.dart) | Lifecycle: records monotonic time at `paused`, compares on `resumed`, calls `_engageLock()` only when grace elapsed. Cold start via `_tryColdStartLock()` unchanged. |
| [`biometric_app_lock_policy.dart`](../../apps/mobile/lib/core/auth/biometric_app_lock_policy.dart) | Pure rules: `biometricAppLockShouldEngage` (who may lock) and `biometricAppLockShouldEngageOnResume` (background duration vs grace). |
| [`app_config.dart`](../../apps/mobile/lib/config/app_config.dart) | Single constant [`biometricAppLockResumeGracePeriod`](../../apps/mobile/lib/config/app_config.dart) (30 s). |
| [`monotonic_clock.dart`](../../apps/mobile/lib/core/time/monotonic_clock.dart) | `SystemMonotonicClock` (`Stopwatch`) for production; injectable `FakeMonotonicClock` in tests. |

**Invariants preserved:** No lock during onboarding or when the flag is off; no lock immediately after unlock (`inactive` / prompt paths); profile save does not engage; cold start and process kill always lock when policy allows; sign-out from overlay unchanged.

**Fix:** On `resumed`, engage only if `biometricAppLockShouldEngageOnResume(timeInBackground: …)` is true (monotonic elapsed since `paused`). Shorter background stays unlocked; longer background or cold start locks as before.
