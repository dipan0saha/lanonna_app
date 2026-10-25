# RCA: Dev release APKs signed with upload keystore when `key.properties` exists

## Symptom

After the owner created `apps/mobile/android/key.properties` for upcoming Play upload signing, **dev** release APKs built with:

```bash
scripts/flutter_build_apk.sh --release --target-platform android-arm64 --dart-define-from-file=flavors/dev.json
```

were signed with the **upload** certificate instead of the **debug** certificate. That SHA-1 does not match the debug key registered in Firebase project **lanonna-dev**, so **Google Sign-In** fails and testers must reinstall to recover a matching signing identity.

## Root cause

[PR #348](https://github.com/dipan0saha/lanonna_app/pull/348) added release signing via gitignored `key.properties` and wired `buildTypes.release.signingConfig` like this:

- If `key.properties` exists → always use the `release` signing config (upload keystore).
- Else if `APP_ENV=prod` (from decoded Flutter `dart-defines`) → no signing config (Gradle task-graph check fails).
- Else → debug keystore.

Gradle correctly decoded `APP_ENV` from the `dart-defines` project property for Firebase / App Link guards, but **signing ignored environment** whenever `key.properties` was present. Local prod prep (`key.properties` on disk) therefore changed dev release artifacts—a coupling the flavor design explicitly avoids elsewhere (prod-only values must not leak into dev builds).

## Related code

| Location | Role |
|----------|------|
| [`apps/mobile/android/app/build.gradle.kts`](../../../apps/mobile/android/app/build.gradle.kts) | `decodeDartDefines()`, `isProdBuild`, `signingConfigs`, `buildTypes.release`, prod-only `gradle.taskGraph.whenReady` checks |
| [`apps/mobile/flavors/dev.json`](../../../apps/mobile/flavors/dev.json) | `APP_ENV=dev` for dev release builds |
| [`apps/mobile/flavors/prod.json`](../../../apps/mobile/flavors/prod.json) | `APP_ENV=prod` for prod release builds |
| [`docs/engineering/mobile-prod-flavor-and-crashlytics.md`](../mobile-prod-flavor-and-crashlytics.md) | Intended signing matrix (updated after this fix) |

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **A. Environment-aware signing in Gradle (chosen)** | Matches existing `dart-defines` / `APP_ENV` pattern; no `productFlavors`; dev command unchanged; `key.properties` only affects prod release | Requires documenting that dev release ignores `key.properties` |
| B. Separate `key.properties` paths per env | Could allow optional dev upload signing | Extra files, easy to misconfigure; contradicts dev Firebase debug SHA |
| C. Gradle `productFlavors` (`dev` / `prod`) | Familiar Android pattern | Breaks agreed one-command dev APK flow and CI; duplicates Dart flavor surface |
| D. Rename / relocate keystore file for prod only | Quick local workaround | Does not fix the build for other contributors; secrets ergonomics unchanged |

## Fix

- **Non-prod release** (`APP_ENV` ≠ `prod`): always `signingConfigs.debug`; do not read `key.properties` for signing.
- **Prod release** (`APP_ENV` = `prod`): require `key.properties` and sign with upload keystore; keep existing release-task `GradleException` when `key.properties` is missing or `google-services.json` is still **lanonna-dev**.

## Verification

1. With `key.properties` present, dev release APK → `apksigner verify --print-certs` shows the **debug** certificate (same as `~/.android/debug.keystore`).
2. Prod release without `key.properties` → Gradle fails with the existing prod release message before packaging.
3. Prod release with `key.properties` and prod Firebase config → upload keystore (after Dart prod placeholder guards pass).
