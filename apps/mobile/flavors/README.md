# Flutter flavor dart-defines

| File | Purpose |
|------|---------|
| `dev.json` | Dev API, App Link host, `APP_ENV=dev` (committed) |
| `prod.json` | Prod template with `__PROD_*` placeholders — must be filled before prod ship |
| `dev.json.example` | Local copy template |

Copy `dev.json.example` to `dev.json` (gitignored if you prefer local-only) and set `API_BASE_URL` to the current Cloud Run API:

```bash
gcloud run services describe api --project lanonna-dev --region us-central1 --format='value(status.url)'
```

Run the app with:

```bash
flutter run --dart-define-from-file=flavors/dev.json
```

Keep committed `dev.json` in sync when the dev API service URL changes.

Release and profile builds read `API_BASE_URL` from this file. If the key is missing or empty, compilation fails with `Release builds must set API_BASE_URL via --dart-define-from-file=flavors/dev.json`. Debug builds without the file use the dev URL baked into `AppConfig`.

`APP_LINK_HOST` must match the Firebase Hosting origin used for invites and email verification (`{project_id}.firebaseapp.com`). Android reads it from Flutter `dart-defines`; iOS syncs it in a build phase.

**Prod:** see [mobile-prod-flavor-and-crashlytics.md](../../../docs/engineering/mobile-prod-flavor-and-crashlytics.md). Prod release APKs require `android/key.properties`. Dev release APKs always use the debug keystore even if `key.properties` exists locally.

```bash
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=flavors/prod.json
```
