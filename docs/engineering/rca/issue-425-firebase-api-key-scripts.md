# RCA: Infra smoke cannot read Firebase API key (#425)

## Summary

`./scripts/infra-smoke-display-upload.sh` (and `seed_qa_gallery_photo.sh`) fail before step 1 when `FIREBASE_API_KEY` is unset:

```
AttributeError: 'NoneType' object has no attribute 'group'
```

The full smoke passes when `FIREBASE_API_KEY` is set manually from dev options.

## Root cause

Since the prod flavor split (#348), `apps/mobile/lib/firebase_options.dart` is a **barrel** that re-exports `resolveFirebaseOptions` and `DevFirebaseOptions` aliases — it contains no `apiKey:` literal. Both scripts still regex-parse that file.

Runtime and tests use `apps/mobile/lib/firebase/firebase_options_dev.dart` (or prod) via `APP_ENV`.

## Fix

| Layer | Change |
|-------|--------|
| `scripts/read_firebase_api_key.sh` | Shared helper: read `apps/mobile/lib/firebase/firebase_options_${APP_ENV:-dev}.dart`, extract the first `apiKey`, exit with a clear message if missing. |
| `infra-smoke-display-upload.sh`, `seed_qa_gallery_photo.sh` | Call the helper when `FIREBASE_API_KEY` is unset. |
| Tests | Shell-level test or script self-check documented in engineering docs; no secrets in repo. |

## References

- GitHub #425, #348
- `scripts/infra-smoke-display-upload.sh`
- `scripts/seed_qa_gallery_photo.sh`
- `apps/mobile/lib/firebase/firebase_options_dev.dart`
