# RCA: Signed-in cold start gap before authorized API requests

## Symptom

On a signed-in Android cold launch against dev, authorized Home/startup reads (`/v1/onboarding/status`, `/v1/babies`, `/v1/babies/{id}/home-summary`, `/v1/me/account`, `/v1/me/notifications/unread-count`, etc.) often begin **~0.75–0.9 s after** process start. Logs may show `GET /v1/app/version?platform=android` slightly earlier, which can look like the version check is serializing everything behind it. Home feels slow to populate even though the version gate is non-blocking for supported builds.

## What we traced

| Layer | File | Role on cold start |
|-------|------|-------------------|
| Entry | [`main.dart`](../../../apps/mobile/lib/main.dart) | Firebase + parallel `bootstrapLaNonnaApp` + App Check activation; signed-in [`prefetch`](../../../apps/mobile/lib/core/app_check/app_check_token_source.dart) overlaps bootstrap. |
| Graph | [`bootstrap.dart`](../../../apps/mobile/lib/bootstrap.dart) | Builds `ApiClient`, repos, `AppSession`; `startSignedInStartupPrefetch` when signed in; **no HTTP** before `runApp` (by design since #241). |
| Version | [`app_version_service.dart`](../../../apps/mobile/lib/core/version/app_version_service.dart) | Version check started once from bootstrap; ~**15 ms** server, ~**0.2 s** client RTT — **not** the ~0.9 s gap. |
| Tokens | [`api_client.dart`](../../../apps/mobile/lib/core/api/api_client.dart) | Authorized GETs await Firebase **ID token** + **App Check** header in parallel; version uses **`getJsonPublic`** (no tokens). |
| App Check | [`app_check_bootstrap.dart`](../../../apps/mobile/lib/core/app_check/app_check_bootstrap.dart), [`app_check_token_source.dart`](../../../apps/mobile/lib/core/app_check/app_check_token_source.dart) | **Primary cold-start blocker** when attestation runs (see [app-check-dev-release-play-integrity.md](app-check-dev-release-play-integrity.md)). |
| Router / shell / home | [`app_router.dart`](../../../apps/mobile/lib/core/router/app_router.dart), [`shell_chrome_sync.dart`](../../../apps/mobile/lib/features/shell/presentation/shell_chrome_sync.dart), [`home_screen.dart`](../../../apps/mobile/lib/features/home/home_screen.dart) | Mount-time reads deduped via caches / `*FreshFor` helpers after #361 prefetch. |

## Root cause (measured on emulator, dev release APK, main @ b0f7b3e)

The ~0.9 s gap is **Firebase App Check attestation**, not `/v1/app/version` and not the Firebase ID token.

| Phase | Duration |
|-------|----------|
| To Play Integrity request | ~150–190 ms |
| Play Integrity | ~480–635 ms |
| Token exchange (Firebase) | ~170–240 ms → **403** `App attestation failed` |

**Why dev release hit Play Integrity:** `app_check_bootstrap.dart` previously chose the debug provider only for `kDebugMode` or `MAESTRO_SEMANTICS`, so **dev release** APKs (`APP_ENV=dev`) used **Play Integrity**, which cannot succeed for sideloaded dev builds. Nothing was cached after failure, so **every cold launch** (and every authorized request after SDK backoff cleared, e.g. opening Fun tab ~**820 ms** later) re-attested.

**Not the cause:** version wall time (~0.2 s), deferred widget-tree scheduling alone (#361 moved prefetch to bootstrap but did not remove the App Check wait), or ID-token latency.

## Fix (architecture)

### Startup prefetch (#361 / main @ 8bcf6a5)

- **`AppVersionService`** — version check runs **once per process** from **`bootstrapLaNonnaApp`**. `AppVersionGate` only watches it.
- **`startSignedInStartupPrefetch`** — when `currentUser != null`, start onboarding status, account, unread, baby resolve, and speculative home-summary **in parallel with** the version check. Removed duplicate post-frame `refreshFromApi` and the force-update notify loop.
- **Does not remove the App Check wait** on dev release until the provider selection fix lands ([#366](https://github.com/dipan0saha/lanonna_app/issues/366)).

### App Check ([#366](https://github.com/dipan0saha/lanonna_app/issues/366))

- Select provider by **`APP_ENV`**: non-prod → debug provider + registered debug token; prod → Play Integrity / App Attest (never debug fallback).
- **`AppCheckTokenSource`**: cool down after failed attestation so requests do not each trigger a new Play Integrity round trip.

## How to verify (emulator + dev API logs)

1. Signed-in user with main-app access; kill app.
2. `adb shell am start -W -n com.lanonna.lanonna/com.lanonna.lanonna.MainActivity` (dev release uses the same application id with debug signing).
3. With App Check fixed for dev release: authorized GETs should not wait ~0.9 s for a failing Play Integrity exchange; `/v1/app/version` and signed-in GETs overlap within a few hundred ms.
4. Optional: temporarily set a high `minimum_version` in `app_versions` — app shows update block, no Home interaction.
5. Airplane mode cold start — cached shell/home/offline banner behavior unchanged.

## Related

- [app-check-dev-release-play-integrity.md](app-check-dev-release-play-integrity.md) — App Check RCA and prod checklist pointers
- [perf-audit-2026-10.md](../perf-audit-2026-10.md) — PERF-MOB startup notes
- [development.md](../development.md) — cold-start table
- [#336](https://github.com/dipan0saha/lanonna_app/pull/336) — parallel bootstrap + App Check prefetch
- [#346](https://github.com/dipan0saha/lanonna_app/pull/346) — biometric cold-start lock settlement
- [#361](https://github.com/dipan0saha/lanonna_app/pull/361) — signed-in startup prefetch; removed duplicate requests, not the App Check gap
