# Mobile prod flavor and Crashlytics

| Field | Value |
|-------|--------|
| **Status** | Implemented (mobile); prod Firebase project still owner-owned |
| **Last updated** | 2026-10-20 |
| **Related** | [pre-prod-consolidation.md](pre-prod-consolidation.md) §2 / §4, [platform-architecture.md](platform-architecture.md), [operations.md](operations.md), [open-gaps.md](open-gaps.md) H-01 |

## Goals

1. **Prod flavor** — `flavors/prod.json` mirrors dev with explicit placeholders; release/profile **prod** builds fail at compile time or at startup if placeholders remain, so a prod binary never silently talks to dev.
2. **Single config surface** — runtime values flow through [`AppConfig`](../../apps/mobile/lib/config/app_config.dart) and `--dart-define-from-file`; native App Link hosts follow the same defines (Android via Gradle + `manifestPlaceholders`; iOS via a build-phase script reading Flutter `DART_DEFINES`).
3. **Release signing** — upload keystore via gitignored `key.properties`; dev release keeps optional debug signing; **prod release requires** `key.properties`.
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

- **Dev command unchanged:** `flutter build apk --release --target-platform android-arm64 --dart-define-from-file=flavors/dev.json` with existing `com.lanonna.lanonna` and dev `google-services.json`.
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
| Release, `APP_ENV` ≠ `prod` | optional | Release config if present, else debug (local dev release) |
| Release, `APP_ENV` = `prod` | **required** | Release config; Gradle fails configuration otherwise |

Document keystore creation in [apps/mobile/android/README.md](../../apps/mobile/android/README.md) (or flavors README); do not generate keys in repo.

### Crashlytics and errors

- **Package:** `firebase_crashlytics` + Android Gradle Crashlytics plugin (with existing `google-services`).
- **Abstraction:** `CrashReporter` + `NoOpCrashReporter` + `FirebaseCrashReporter` in `lib/core/observability/`.
- **Wiring:** `configureAppErrorReporting()` chains `FlutterError.onError` and `PlatformDispatcher.instance.onError` once: it records to Crashlytics, then calls the handler that was already installed (framework default printing, or any earlier app/test handler). Installed only when collection is enabled.
- **Collection:** `AppConfig.crashlyticsCollectionEnabled` — always true when `APP_ENV=prod`; in dev, `CRASHLYTICS_ENABLED` dart-define (`true`/`false`), default **true** when `dart.vm.product` (release) and unset.
- **User id:** set/clear on auth state changes using Firebase **uid** only (never email or display name).

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

## Build commands

**Dev (unchanged):**

```bash
cd apps/mobile
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=flavors/dev.json
```

**Prod (after owner fills `flavors/prod.json`, keystore, and `flutterfire configure`):**

```bash
cd apps/mobile
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=flavors/prod.json
# iOS: same --dart-define-from-file=flavors/prod.json on flutter build ipa / ios
```

A prod release APK/AAB fails before any task runs (Gradle task-graph check, so a prod debug `flutter run` still works) without `android/key.properties`, or when `android/app/google-services.json` is missing or still points at `lanonna-dev`. With both in place it still fails at the Dart compile guard until the `__PROD_` placeholders are replaced.
