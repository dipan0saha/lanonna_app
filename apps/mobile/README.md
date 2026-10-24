# La Nonna — mobile (Flutter)

Flutter client: Firebase Auth, FCM, App Check, display encode before upload, disk-cached signed image URLs, API client. See [pre-beta-qa.md](../../docs/engineering/pre-beta-qa.md).

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json
```

Dev API default: `https://api-r27szgit5q-uc.a.run.app` (override in `flavors/dev.json`).

**Package:** `lanonna` · **Bundle ID:** `com.lanonna.lanonna`

Firebase config files are environment-specific — obtain from Firebase console; do not commit production keys in public repos without review.

**Before a PR** (full local gate from repo root, Flutter 3.38.9):

```bash
cd ../.. && ./scripts/premerge_check.sh
# optional UI regression on emulator-5554:
./scripts/premerge_check.sh --e2e
```

Quick mobile-only iteration: `bash scripts/check-no-material-chips.sh`, `dart run tool/check_hardcoded_user_strings.dart .`, `flutter analyze --no-fatal-infos`, `flutter test --exclude-tags golden` (run goldens on macOS).

**Conventions:** theme tokens (`AppSpacing`, `AppMetrics`, `AppButtonStyles`, `context.textStyles`) and shared widgets in `lib/core/` — see [mobile-prototype-parity.md](../../docs/engineering/mobile-prototype-parity.md); typed server enums, `apiErrorMessage` / `LocalizedFailure`, and offset paging (`core/api/offset_page.dart`) — see [development.md](../../docs/engineering/development.md).

Parent repo layout: [docs/engineering/development.md](../../docs/engineering/development.md).
