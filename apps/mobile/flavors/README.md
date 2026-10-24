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

**App Check:** `APP_ENV=dev` selects the Firebase **debug** provider (not Play Integrity). Optional `APP_CHECK_DEBUG_TOKEN` in `maestro/local.env` — see [app-check-dev-release-play-integrity.md](../../../docs/engineering/rca/app-check-dev-release-play-integrity.md).

Release builds should pass a **build stamp** so Crashlytics can distinguish binaries (see `scripts/build_stamp.sh`):

```bash
eval "$(bash scripts/build_stamp.sh)"
flutter build apk --release --target-platform android-arm64 \
  --build-number="${BUILD_NUMBER}" \
  --dart-define=BUILD_GIT_SHA="${BUILD_GIT_SHA}" \
  --dart-define=BUILD_NUMBER="${BUILD_NUMBER}" \
  --dart-define-from-file=flavors/dev.json
```

Prod: set `REQUIRE_BUILD_STAMP=1` before `build_stamp.sh` and use `flavors/prod.json` — [mobile-prod-flavor-and-crashlytics.md](../../../docs/engineering/mobile-prod-flavor-and-crashlytics.md).
