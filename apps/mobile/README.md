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

**Before a PR** (same checks as CI, Flutter 3.38.9):

```bash
bash scripts/check-no-material-chips.sh
dart run tool/check_hardcoded_user_strings.dart .   # all user copy in lib/l10n/app_en.arb
flutter analyze --no-fatal-infos
flutter test --exclude-tags golden                  # run golden tests on macOS
```

**Conventions:** theme tokens (`AppSpacing`, `AppMetrics`, `AppButtonStyles`, `context.textStyles`) and shared widgets in `lib/core/` — see [mobile-prototype-parity.md](../../docs/engineering/mobile-prototype-parity.md); typed server enums, `apiErrorMessage` / `LocalizedFailure`, and offset paging (`core/api/offset_page.dart`) — see [development.md](../../docs/engineering/development.md).

Parent repo layout: [docs/engineering/development.md](../../docs/engineering/development.md).
