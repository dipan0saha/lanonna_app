# Mobile prod flavor and Crashlytics

| Field | Value |
|-------|--------|
| **Status** | Implemented (mobile); prod Firebase project still owner-owned |
| **Last updated** | 2026-10-25 |
| **Related** | [pre-prod-consolidation.md](pre-prod-consolidation.md) §2 / §4, [platform-architecture.md](platform-architecture.md), [operations.md](operations.md), [open-gaps.md](open-gaps.md) H-01 |

## Goals

1. **Prod flavor** — `flavors/prod.json` mirrors dev with explicit placeholders; release/profile **prod** builds fail at compile time or at startup if placeholders remain, so a prod binary never silently talks to dev.
2. **Single config surface** — runtime values flow through [`AppConfig`](../../apps/mobile/lib/config/app_config.dart) and `--dart-define-from-file`; native App Link hosts follow the same defines (Android via Gradle + `manifestPlaceholders`; iOS via a build-phase script reading Flutter `DART_DEFINES`).
3. **Release signing** — upload keystore via gitignored `key.properties` for **prod release only**; dev release always uses the debug keystore (even when `key.properties` exists); **prod release requires** `key.properties`.
4. **Crashlytics** — `firebase_crashlytics` wired through one error-handling module; collection on for prod, dev controlled by dart-define (default **on** in dev release for owner testing); tests use a no-op reporter.

## Analysis

### What was wrong

| Area | Problem |
|------|---------|
| Flavors | Only `flavors/dev.json`; no prod template or guards |
| Native links | `lanonna-dev.firebaseapp.com` hard-coded in `AndroidManifest.xml` and `Runner.entitlements` |
| Firebase options | Single `firebase_options.dart` always points at **lanonna-dev** |
| Signing | Release builds always used the debug keystore (H-01) |
| Crashlytics | Mentioned in architecture; not integrated in the app |
| Tests | N/A for Firebase today; new code must stay testable without Firebase |

### Constraints

- **Dev command unchanged:** `scripts/flutter_build_apk.sh --release --target-platform android-arm64 --dart-define-from-file=flavors/dev.json` with existing `com.lanonna.lanonna` and dev `google-services.json`.
- **No prod GCP/Firebase yet** — prod `FirebaseOptions` stay a typed placeholder until `flutterfire configure` against `lanonna-prod` (or chosen project).
- **Public repo** — no keystore, passwords, or owner emails in git.

## Design choices

### Why not Gradle `productFlavors`?

`productFlavors` would change default variant names, CI, and the exact dev APK command. Instead:

- **Dart:** `APP_ENV`, `API_BASE_URL`, `APP_LINK_HOST`, `CRASHLYTICS_ENABLED`, etc. from `--dart-define-from-file` (same as today for API URL).
- **Android:** Gradle decodes Flutter’s `dart-defines` property (base64 `KEY=value` list) and sets `manifestPlaceholders["appLinkHost"]`. Fallback when absent: `lanonna-dev.firebaseapp.com` (debug builds without a flavor file).
- **iOS:** `Runner.entitlements` uses `applinks:$(APP_LINK_DOMAIN)`. `Debug.xcconfig` / `Release.xcconfig` default `APP_LINK_DOMAIN` to the dev host. `ios/Runner/sync_app_link_domain.sh` (bash Run Script phase) decodes `APP_LINK_HOST` from `DART_DEFINES` in `Flutter/Generated.xcconfig`, rejects anything that is not a plain hostname (e.g. an unreplaced `__PROD_` placeholder), and writes the gitignored `Flutter/AppLink.generated.xcconfig`. Xcode reads build settings before build phases run, so when the host changes (dev → prod) the script writes the override and fails the build; run it again so the entitlement is signed with the new domain.

This keeps one flavor file per environment without a second dimension in Gradle/Xcode schemes.

### Firebase options by environment

| `APP_ENV` | Options source |
|-----------|----------------|
| `dev` (default) | `firebase_options_dev.dart` (current lanonna-dev values) |
| `prod` | `firebase_options_prod.dart` — `currentPlatform` throws `UnsupportedError` with instructions to run `flutterfire configure` until prod apps exist |

Entry: `resolveFirebaseOptions()` in `lib/firebase/firebase_options_resolver.dart`. `main.dart` and FCM background handler call that instead of `DefaultFirebaseOptions` directly.

### Prod placeholder guard

Placeholders in `flavors/prod.json` use the prefix `__PROD_` (e.g. `__PROD_API_BASE_URL__`).

- **Compile time (release/profile, `APP_ENV=prod`):** const guard `prodPlaceholderConfigGuard` in `app_config.dart` (same pattern as `releaseApiBaseUrlGuard`) fails the Dart compile when `API_BASE_URL`, `APP_LINK_HOST` or `GOOGLE_SIGN_IN_SERVER_CLIENT_ID` is still the exact `__PROD_…__` placeholder, is empty, or equals the dev default (no silent dev fallback). The placeholders are compared by equality because `String.startsWith` is not a constant expression; `prod_config_guard_test.dart` keeps the list in sync with `flavors/prod.json`.
- **Runtime:** `ProdConfigGuard.ensureReady()` at startup (before network/Firebase) throws `StateError` with a clear message if placeholders slipped through a debug build.

### Release signing

| Build | `key.properties` | Signing |
|-------|------------------|---------|
| Debug | ignored | Debug keystore |
| Release, `APP_ENV` ≠ `prod` | **ignored** | Debug keystore (matches lanonna-dev Firebase debug SHA) |
| Release, `APP_ENV` = `prod` | **required** | Upload keystore; Gradle fails release tasks otherwise |

See [rca/release-signing-environment.md](rca/release-signing-environment.md) for why dev release must not pick up the upload key when `key.properties` exists locally.

Document keystore creation in [apps/mobile/android/README.md](../../apps/mobile/android/README.md) (or flavors README); do not generate keys in repo.

### Crashlytics and errors

- **Package:** `firebase_crashlytics` + Android Gradle Crashlytics plugin (with existing `google-services`).
- **Abstraction:** `CrashReporter` + `NoOpCrashReporter` + `FirebaseCrashReporter` in `lib/core/observability/`.
- **Wiring:** `configureAppErrorReporting()` chains `FlutterError.onError` and `PlatformDispatcher.instance.onError` once: it records to Crashlytics, then calls the handler that was already installed (framework default printing, or any earlier app/test handler). Installed only when collection is enabled.
- **Collection:** `AppConfig.crashlyticsCollectionEnabled` — always true when `APP_ENV=prod`; in dev, `CRASHLYTICS_ENABLED` dart-define (`true`/`false`), default **true** when `dart.vm.product` (release) and unset.
- **User id:** set/clear on auth state changes using Firebase **uid** only (never email or display name).
- **Build stamp:** at startup, `startCrashReporting` sets Crashlytics custom keys `build_git_sha`, `build_number`, and `build_env` from dart-defines (`BUILD_GIT_SHA`, `BUILD_NUMBER`, `APP_ENV`). Missing SHA/number in non-prod builds report as `unknown` and never crash. **Prod release/profile** must pass both defines (compile-time `prodBuildStampGuard` in `app_config.dart`, runtime `ensureProdConfigReady()` for prod debug runs). Every repo Android binary build goes through `flutter_build_apk.sh` or `flutter_build_appbundle.sh`, which source `flutter_build_stamp.sh` → `build_stamp.sh` → `derive_android_version_code.sh` and pass `--build-number` plus the defines; with `flavors/prod.json` the shell fails when git or the stamp is unavailable. See [rca/issue-444-build-number-regression.md](rca/issue-444-build-number-regression.md).

### Tests

- Unit tests for `ProdConfigGuard`, `AppConfig` crashlytics flag resolution, and `configureAppErrorReporting` (no-op reporter, handlers invoke reporter).
- Existing tests unchanged; no `Firebase.initializeApp` in test harness.

## Owner follow-up (not in this PR)

1. Create **upload keystore** and `android/key.properties` (see android README).
2. Create **lanonna-prod** (or chosen) Firebase/GCP project; register prod Android/iOS apps (application ID TBD).
3. Run **`flutterfire configure`** for prod; replace `firebase_options_prod.dart` generated output.
4. Fill **`flavors/prod.json`** (API URL, invite host, Google Sign-In web client ID).
5. Firebase console: enable **Crashlytics** for prod (and dev if desired). On **dev** release builds (`flavors/dev.json`), use **Settings → Send test crash (Crashlytics)** or a one-off build with `--dart-define=CRASHLYTICS_TEST_CRASH_ON_START=true` (crashes ~3s after launch; relaunch once to upload).
6. Play Console / App Store signing and App Links verification with prod `assetlinks` / AASA (hosting deploy — separate infra PR).
7. <a id="prod-app-check"></a>**App Check before `APP_CHECK_ENFORCE=true`** (prod uses Play Integrity / App Attest only; see [rca/app-check-dev-release-play-integrity.md](rca/app-check-dev-release-play-integrity.md)):
   - Firebase Console → **lanonna-prod** → App Check → register the Android app with **Play Integrity**, and add the **upload key** and **Play app signing** certificate SHA-256 fingerprints (Play Console → Setup → App signing; `keytool -list -v` for the upload keystore).
   - Link the Firebase Android app to the Google Play project (Play Integrity provider).
   - Raise the App Check token TTL (e.g. 12–24 h) under App Check → Apps → Android → Settings, so cold starts reuse the stored token.
   - iOS: register the prod bundle id with **App Attest** (DeviceCheck fallback per Firebase defaults).
   - Deploy the API with `APP_CHECK_ENFORCE=true` ([`infra/env/prod.api.env`](../../infra/env/prod.api.env)) and smoke-test a build from Play internal testing.

## Build commands

**Dev (`flutter_build_apk.sh` stamps git SHA + monotonic build number):**

```bash
cd apps/mobile
scripts/flutter_build_apk.sh --release --target-platform android-arm64 \
  --dart-define-from-file=flavors/dev.json
```

Or from repo root: `./scripts/ship_release_apk_to_drive.sh` (uses the same wrapper). Debug emulator builds: `./maestro/scripts/build-install.sh` (also the wrapper).

`BUILD_NUMBER` / `versionCode` is the seconds from 2020-01-01T00:00:00Z to HEAD's committer time (`derive_android_version_code.sh`), so a squash merge on `main` gets a higher code than the branch it merged (issue #444). The same value goes to Gradle `versionCode` (`--build-number`), the `BUILD_NUMBER` dart-define and Crashlytics `build_number`. `BUILD_GIT_SHA` is `git rev-parse --short HEAD` (or `unknown` when git is unavailable). Keep the **marketing version** (`version:` in `pubspec.yaml`, Android `versionName`) on semver and bump it per Play release; wrappers always pass `--build-number`.

**Play-bound builds are guarded.** Every AAB (any flavor) and every prod-flavor build (`APP_ENV=prod` from `--dart-define-from-file` or `--dart-define`) runs `android_release_guard.sh`: clean tree, HEAD on `origin/main` (freshly fetched), and a `versionCode` strictly greater than the highest `android-vc-<code>` tag on origin. A `BUILD_NUMBER` override is accepted only when it clears the same bar. After Play accepts an upload, record it from the same checkout with `scripts/record_android_release.sh <versionCode>` (creates and pushes the tag). Dev APKs are not guarded: branch builds can carry a higher code than an older `main` commit, so to go back to an older debug build use `adb install -r -d` (debuggable only) or uninstall first.

**Prod (after owner fills `flavors/prod.json`, keystore, and `flutterfire configure`):**

```bash
cd apps/mobile
scripts/flutter_build_apk.sh --release --target-platform android-arm64 \
  --dart-define-from-file=flavors/prod.json
scripts/flutter_build_appbundle.sh --release \
  --dart-define-from-file=flavors/prod.json
# iOS: not wired yet; pass the same stamp defines on flutter build ipa
```

Prod release fails in the wrapper (release guard), at compile time, or at `ensureProdConfigReady()` if `BUILD_GIT_SHA` or `BUILD_NUMBER` is missing.

A prod release APK/AAB fails before any task runs (Gradle task-graph check, so a prod debug `flutter run` still works) without `android/key.properties`, or when `android/app/google-services.json` is missing or still points at `lanonna-dev`. With both in place it still fails at the Dart compile guard until the `__PROD_` placeholders are replaced.
