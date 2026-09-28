# La Nonna — mobile (Flutter)

Flutter client: Firebase Auth, App Check, FCM, API client, **display image encode** before GCS upload, local image cache.

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=flavors/dev.json
```

Dev API default: `https://api-1008830071001.us-central1.run.app` (override in `flavors/dev.json`).

**Package:** `lanonna` · **Bundle ID:** `com.lanonna.lanonna`

Firebase config files are environment-specific — obtain from Firebase console; do not commit production keys in public repos without review.

Parent repo layout: [docs/development.md](../../docs/development.md).
