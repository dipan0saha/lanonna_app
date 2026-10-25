# RCA: Dev release APK uses Play Integrity; every authorized request waits on failing attestation

## Summary

Dev **release** builds (`scripts/flutter_build_apk.sh --release --dart-define-from-file=flavors/dev.json`) used the Firebase **Play Integrity** App Check provider because provider selection followed `kDebugMode`, not `APP_ENV`. Sideloaded dev APKs cannot pass Play Integrity attestation. The Firebase SDK returned **403 App attestation failed**, cached nothing, and **`ApiClient`** awaited App Check on every authorized request — ~**0.9 s** per cold launch on emulator (measured main @ b0f7b3e).

GitHub: [#366](https://github.com/dipan0saha/lanonna_app/issues/366)

## Timeline (emulator, 5 cold launches, dev release APK)

| Phase | Duration |
|-------|----------|
| To Play Integrity request | ~150–190 ms |
| Play Integrity | ~480–635 ms |
| Token exchange | ~170–240 ms → **403** `App attestation failed` |

After SDK backoff cleared, the next authorized request re-attested (e.g. opening Fun tab **~820 ms** later).

## Contributing factors

| Layer | Behavior |
|-------|----------|
| [`app_check_bootstrap.dart`](../../../apps/mobile/lib/core/app_check/app_check_bootstrap.dart) | Debug provider only when `kDebugMode` or `MAESTRO_SEMANTICS`; dev release → Play Integrity. |
| [`api_client.dart`](../../../apps/mobile/lib/core/api/api_client.dart) | Awaits App Check for authorized requests (10 s cap). |
| [`app_check_token_source.dart`](../../../apps/mobile/lib/core/app_check/app_check_token_source.dart) | Single-flight reads with no memory of failure → repeated attestations. |
| API | Dev Cloud Run: `APP_CHECK_ENFORCE=false` ([`deploy.sh`](../../../services/api/scripts/deploy.sh)). Prod: `APP_CHECK_ENFORCE=true` in [`infra/env/prod.api.env`](../../../infra/env/prod.api.env). |

Missing App Check on dev is acceptable when enforce is off; **waiting** on a failing attestation is not.

## Fix

1. **Provider by `APP_ENV`** ([`app_check_bootstrap.dart`](../../../apps/mobile/lib/core/app_check/app_check_bootstrap.dart)): a compile-time constant; `APP_ENV != prod` → Android/iOS **debug** providers; `prod` → Play Integrity / App Attest, with no debug fallback (an unregistered prod build fails attestation and the API rejects it when enforced).
2. **Non-prod debug token:** optional `APP_CHECK_DEBUG_TOKEN` in `apps/mobile/maestro/local.env` (git-ignored). Gradle puts it in `BuildConfig` only when `APP_ENV != prod` (every build type); prod builds always get an empty field, so a prod APK cannot carry it. It is never logged by the app. Register once: `apps/mobile/maestro/scripts/register-app-check-debug.sh` against the **lanonna-dev** Firebase project. Without a pin, copy the UUID from logcat (`DebugAppCheckProvider`) and register in Firebase Console → App Check → Apps → Manage debug tokens.
3. **`AppCheckTokenSource`:** after a failed read, a **failure cool-down** (default 30 s) returns `null` at once instead of calling `getToken()` again on every request (the request would have gone without the header anyway). A token from the SDK's auto-refresh (`onTokenChange`) ends the cool-down, so a valid token is never held back. Successful tokens stay SDK-owned (disk + auto-refresh).
4. **Prefetch:** the signed-in [`prefetch`](../../../apps/mobile/lib/core/app_check/app_check_token_source.dart) is now the first statement of `bootstrapLaNonnaApp` (before the crash-reporting await), which `main` calls synchronously right after activating App Check.

## Prod checklist

See [mobile-prod-flavor-and-crashlytics.md → App Check](../mobile-prod-flavor-and-crashlytics.md#prod-app-check) — Play Integrity SHA-256, Play Console link, App Check token TTL.

## Related

- [startup-version-check-serialization.md](startup-version-check-serialization.md) — startup gap often mis-attributed to version RTT
- [pre-beta-qa.md](../pre-beta-qa.md) — debug token registration for QA
- [development.md](../development.md) — App Check on Android dev
