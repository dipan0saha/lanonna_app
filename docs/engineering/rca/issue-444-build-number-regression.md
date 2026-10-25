# RCA: Android versionCode regresses after squash merge (#444)

## Summary

Stamped Android builds derived `BUILD_NUMBER` / `versionCode` from `git rev-list --count HEAD`. After a squash merge, `main` often had a **lower** count than the feature branch that was just merged (e.g. `main` @ `fbd2cf8` → **239**, PR branch @ `2e5e855` → **241**). Devices refused downgrade installs (`INSTALL_FAILED_VERSION_DOWNGRADE`), and Play would reject uploads that are not strictly higher than every prior `versionCode`. Crashlytics `build_number` was not reliably ordered across builds.

## Root cause

1. **`apps/mobile/scripts/build_stamp.sh`** set `BUILD_NUMBER` to `git rev-list --count HEAD` (unless `BUILD_NUMBER` or `GITHUB_RUN_NUMBER` was set in the environment).
2. **`apps/mobile/scripts/flutter_build_apk.sh`** ran `build_stamp.sh`, passed `--dart-define=BUILD_NUMBER=…` and `--build-number=…` into Flutter.
3. **Flutter / Gradle** map `--build-number` to Android `versionCode` (`pubspec.yaml` documents this; `android/app/build.gradle.kts` uses `flutter.versionCode`).
4. **Crashlytics** reads the same value at runtime via `BUILD_NUMBER` → `BuildMetadata.buildNumber` → custom key `build_number` (with `build_git_sha` and `build_env`).

`rev-list --count` is the number of commits reachable from **current `HEAD`**, not a monotonic release counter. A feature branch accumulates every commit on the branch. A **squash merge** adds one new commit on `main` and drops the individual branch commits from `main`’s history, so `main`’s count can be **less than** the count at the branch tip the developer already shipped—exactly the #444 repro.

Alternatives considered:

| Option | Why not alone |
|--------|----------------|
| `rev-list --count HEAD` (status quo) | Regresses on squash merge (#444). |
| First-parent count on `main` | Not defined for arbitrary branch `HEAD`; branch builds still disagree with `main` and with each other. |
| `GITHUB_RUN_NUMBER` | No GitHub Actions in this repo; builds run on developer Macs. |
| Wall-clock time at build | Not reproducible for the same release commit. |

**Chosen scheme:** `versionCode = max(FLOOR, committer_unix(HEAD) − EPOCH)` with `EPOCH = 2020-01-01T00:00:00Z` and `FLOOR = 300` (above installed dev builds ~239–241). Same commit always yields the same integer; squashed commits get a new committer time at merge, so `main` after squash is **≥** the branch tip build; values stay well under Play’s `2_100_000_000` cap. **`BUILD_GIT_SHA`** remains the traceability key for Crashlytics and support. Explicit `BUILD_NUMBER` in the environment still overrides (local experiments only).

## Fix

| Layer | Change |
|-------|--------|
| `derive_android_version_code.sh` | Single derivation: committer timestamp offset + floor + Play max guard; honors `BUILD_NUMBER` override. |
| `build_stamp.sh` | Calls derivation; drops `rev-list` / `GITHUB_RUN_NUMBER`; prod still fails loud via `REQUIRE_BUILD_STAMP`. |
| `flutter_build_stamp.sh` | Shared stamp args for all Flutter Android wrappers. |
| `flutter_build_apk.sh` | Sources shared stamp (unchanged entrypoint for APKs). |
| `flutter_build_appbundle.sh` | New AAB wrapper using the same stamp. |
| Docs | Build stamp / release runbooks updated to describe the scheme. |

## Impact analysis

| Surface | Detail | Covered by |
|---------|--------|------------|
| **Dev release APK** | `scripts/flutter_build_apk.sh --release --dart-define-from-file=flavors/dev.json`; `./scripts/ship_release_apk_to_drive.sh` | `test_flutter_build_apk_script.py`, `test_android_version_code.py` |
| **Dev debug APK** | `maestro/scripts/build-install.sh` → `flutter_build_apk.sh --debug` + `flavors/dev.json` | `test_flutter_build_apk_script.py` |
| **Dev release x86_64 APK** | `./scripts/ship_release_apk_x86_64_to_drive.sh` | `test_flutter_build_apk_script.py` (`test_repo_apk_scripts_use_the_wrapper`) |
| **Prod release APK** | `flutter_build_apk.sh --release` + `flavors/prod.json`; `REQUIRE_BUILD_STAMP=1` | `test_flutter_build_apk_script.py` (`test_prod_build_without_git_fails_loudly`), `test_android_version_code.py` (prod derive failure) |
| **Prod release AAB** | `flutter_build_appbundle.sh --release` + `flavors/prod.json` | `test_flutter_build_apk_script.py` (no direct `flutter build appbundle`), `test_android_version_code.py` |
| **Gradle `versionCode`** | Flutter `--build-number` → `flutter.versionCode` in `build.gradle.kts` | Wrapper tests assert `--build-number` matches `BUILD_NUMBER` define |
| **`pubspec` version** | Marketing `version:` unchanged; binary `versionCode` only via `--build-number` | Docs |
| **Crashlytics keys** | `build_git_sha`, `build_number`, `build_env` from dart-defines at startup | Docs; stamp tests |
| **`prodBuildStampGuard` / `REQUIRE_BUILD_STAMP`** | Still require non-empty `BUILD_GIT_SHA` and `BUILD_NUMBER` for prod release/profile; shell fails before compile when git/stamp missing | Existing prod guard tests unchanged (still valid) |
| **iOS** | Not wired to wrappers yet; same defines apply when `ipa` is added | N/A (documented) |

## Regression test

| Item | Detail |
|------|--------|
| **Test added** | `scripts/tests/test_android_version_code.py` |
| **Fails on old code** | Squash simulation: `rev-list` count on `main` after squash &lt; branch tip count; with old `rev-list` derivation, `main` `BUILD_NUMBER` would be lower than branch |
| **Passes with fix** | After squash, derived `versionCode` on `main` ≥ branch tip; monotonicity across sequential commits; prod path fails when git unavailable |

## References

- GitHub #444
- `apps/mobile/scripts/derive_android_version_code.sh`
- `apps/mobile/scripts/build_stamp.sh`
- `apps/mobile/scripts/flutter_build_stamp.sh`
- `apps/mobile/scripts/flutter_build_apk.sh`
- `apps/mobile/scripts/flutter_build_appbundle.sh`
- `scripts/tests/test_android_version_code.py`
- `scripts/tests/test_flutter_build_apk_script.py`
