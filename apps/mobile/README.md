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

Parent repo layout: [docs/engineering/development.md](../../docs/engineering/development.md).
