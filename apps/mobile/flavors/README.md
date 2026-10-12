# Flutter flavor dart-defines

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
