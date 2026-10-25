# RCA: Android versionCode regresses after squash merge (#444)

## Summary

Stamped Android builds derived `BUILD_NUMBER` / `versionCode` from `git rev-list --count HEAD`. After a squash merge, `main` often had a **lower** count than the feature branch that was just merged (e.g. `main` @ `fbd2cf8` → **239**, PR branch @ `2e5e855` → **241**). Devices refused the downgrade (`INSTALL_FAILED_VERSION_DOWNGRADE`), and Play rejects any upload whose `versionCode` is not strictly higher than every earlier upload. Crashlytics `build_number` was not ordered across builds either.

## Root cause

1. **`apps/mobile/scripts/build_stamp.sh`** set `BUILD_NUMBER` to `git rev-list --count HEAD` (unless `BUILD_NUMBER` or `GITHUB_RUN_NUMBER` was set).
2. **`apps/mobile/scripts/flutter_build_apk.sh`** passed it as `--dart-define=BUILD_NUMBER=…` and `--build-number=…`.
3. **Flutter / Gradle** map `--build-number` to `versionCode` (`android/app/build.gradle.kts`: `versionCode = flutter.versionCode`).
4. **Crashlytics** reports the same dart-define as custom key `build_number` (`BuildMetadata.buildNumber`).

`rev-list --count` counts commits reachable from `HEAD`; it is not a release counter. A branch accumulates its own commits; a **squash merge** replaces them on `main` with one commit, so `main`'s count can drop below the branch tip that was already built and installed. Nothing compared a new code with the last shipped one, so the regression was only discovered at install time.

There are two separate requirements, and the old design met neither:

- **R1 (dev, convenience):** a later build should normally install over an earlier one.
- **R2 (Play, hard rule):** every uploaded code must be strictly greater than the last released code.

No value derivable from a single commit can guarantee R2 by itself, because "greater than the last release" depends on state outside the commit. R2 needs a check against a record of releases.

## Design

### Derivation (R1): committer seconds since 2020

`versionCode = committer_unix(HEAD) − 1577836800` (2020-01-01T00:00:00Z), in `derive_android_version_code.sh`.

- The same commit always gives the same code (reproducible).
- GitHub's squash merge commits at merge time, which is after every branch commit, so `main` after the merge is higher than the branch tip (the #444 case).
- Today's codes are about 215 million, far above the legacy 239–241 codes on dev devices, so the first new build installs over them. The earlier `max(300, …)` floor could never apply after 2020 and was removed; a commit dated before 2020 now fails instead.
- Play's ceiling is 2,100,000,000, which this scheme reaches in 2086.
- Values are validated as positive decimals with no leading zero and at most Play's maximum. An invalid `BUILD_NUMBER` override fails for every build, including dev (before, it silently became `unknown` and the APK fell back to `versionCode 1`).

Committer time is **not** strictly monotonic. Known ways it breaks:

| Case | Effect |
|------|--------|
| Rebase with `--committer-date-is-author-date`, cherry-pick with a preserved date, `git commit --date` games | A newer `main` commit can carry an older time |
| Clock skew between machines | Same |
| Two commits in the same second | Same code |
| A branch commit made after `main`'s latest commit | Branch build is higher than a later build of that older `main` commit |

So the derivation is good enough for R1 but cannot be trusted alone for R2.

### Release guard (R2): `android_release_guard.sh`

Every **Play-bound** build must pass the guard. A build is Play-bound when it is an **AAB** (any flavor: an AAB only exists to go to Play) or a **prod-flavor** APK/AAB. Prod is detected the way Gradle detects it, from `APP_ENV` in `--dart-define-from-file` (both `=` and space forms) or `--dart-define=APP_ENV=…` (the explicit define wins, as in Flutter). An unreadable flavor file fails the build rather than skipping the check. The guard fails loudly unless:

1. **The tree is clean**: no modified, staged or untracked files. Prod config (`flavors/prod.json`, `firebase_options_prod.dart`) is tracked, so it must be committed to `main` before release; secrets (`key.properties`, keystore, `google-services.json`) are gitignored and unaffected.
2. **HEAD is on `origin/main`**, after a fresh `git fetch origin main` (an unreachable origin fails the build). Branch commits and unpushed local commits are refused.
3. **The code the build will use is strictly greater than the last released code**: the highest `android-vc-<code>` tag on origin, read with `git ls-remote` so unpushed or locally stale tags cannot affect the result. With no tag yet, the build is the first release and is allowed.

The check applies to the final code, so a `BUILD_NUMBER` override for a Play-bound build is accepted only when it is above the last released code. That is the escape hatch for a skewed commit time.

After Play accepts an upload, `record_android_release.sh <code>` runs the same guard, then creates and pushes an annotated `android-vc-<code>` tag on HEAD. A release can only be recorded once, in increasing order.

**Why tags, not a tracked file:** a file is versioned with the code, so an older `main` commit would see an older record and pass. A file also needs a follow-up PR after every release. Tags are global to the repo, survive squash merges, tie each code to the exact commit shipped, and can be checked locally with plain git. Without Play Developer API access, the tags are the local source of truth. If a build is ever uploaded without being recorded, Play itself still rejects the next lower code. The runbook makes recording part of the release step.

### Dev builds stay lenient (documented)

Dev APKs (debug or release, dev flavor) are never guarded: they can be built from branches and dirty trees. A branch build can carry a higher code than a later build of an older `main` commit; to go back, use `adb install -r -d` (debuggable builds) or uninstall. Without git, dev builds still build, stamped `unknown` (no `--build-number`).

### One value everywhere

`flutter_build_stamp.sh` passes the same number as `--build-number` (Gradle `versionCode`, overriding `pubspec.yaml`'s `+1`) and `--dart-define=BUILD_NUMBER` (Crashlytics `build_number`, prod guard). `versionName` stays the `pubspec.yaml` marketing version (`1.0.0`); bump it per Play release, because force-update (`/v1/app/version`) compares `versionName`, not `versionCode`.

Alternatives considered:

| Option | Why not |
|--------|---------|
| `rev-list --count HEAD` (old) | Regresses on squash merge (#444) |
| First-parent count on `main` | Undefined for branch builds; renumbers if history is rewritten |
| `GITHUB_RUN_NUMBER` | No GitHub CI in this repo; builds run on the developer's Mac |
| Wall-clock time at build | Not reproducible for the same commit |
| Committer time alone (first version of this PR) | Not strictly monotonic (see table); no check against what was released |
| Tracked "last release" file | Older commits carry older records; needs a PR per release |

## Fix

| Layer | Change |
|-------|--------|
| `derive_android_version_code.sh` | Single derivation (committer time − 2020 epoch), strict validation, optional `rev`; floor and overridable epoch removed |
| `android_release_guard.sh` | New: clean tree, HEAD on fetched `origin/main`, code > highest `android-vc-*` tag on origin |
| `record_android_release.sh` | New: guard, then tag and push `android-vc-<code>` |
| `build_stamp.sh` | Calls derivation; invalid override fails; `ANDROID_RELEASE_BUILD=1` requires the stamp and runs the guard; `rev-list` and `GITHUB_RUN_NUMBER` removed |
| `flutter_build_stamp.sh` | Shared stamp args; decides Play-bound (AAB or `APP_ENV=prod`) |
| `flutter_build_apk.sh` / `flutter_build_appbundle.sh` | Thin wrappers over the shared stamp (old per-wrapper `flavors/prod.json` substring check and `REQUIRE_BUILD_STAMP` removed) |
| `maestro/scripts/build-install.sh` | One ABI via `--target-platform` instead of `--split-per-abi` |
| Docs | Every build command uses a wrapper; release runbook includes recording the tag |

## Impact analysis

| Surface | Detail | Covered by |
|---------|--------|------------|
| **Installed dev builds (239–241)** | New codes (~215M) install over them with `adb install -r` | Install-over check on emulator (PR #445 report) |
| **Dev debug APK** | `maestro/scripts/build-install.sh` → wrapper `--debug` + dev flavor + `--target-platform` for the device ABI; not guarded. It used `--split-per-abi`, which makes Flutter set `versionCode = abi×1000 + code` (the emulator had `2245` for rev-list 245), so `versionCode` ≠ Crashlytics `build_number`; the wrapper now refuses `--split-per-abi` | `test_flutter_build_apk_script.py`, `test_dev_apk_from_branch_is_not_guarded` |
| **Dev release APKs** | `ship_release_apk_to_drive.sh`, `ship_release_apk_x86_64_to_drive.sh`; not guarded | Same |
| **Any AAB** | `flutter_build_appbundle.sh`; guarded | `test_play_bound_builds_run_the_guard`, `test_aab_from_clean_main_is_stamped` |
| **Prod APK/AAB** | `APP_ENV=prod` via flavor file or define; guarded | Same, plus `test_dart_define_app_env_dev_overrides_prod_file`, `test_unreadable_flavor_file_fails_closed` |
| **`BUILD_NUMBER` override** | Dev: any valid value. Play-bound: must exceed last release. Invalid: always fails | `test_release_override_must_exceed_last_release`, `test_invalid_override_fails_loudly_even_for_dev` |
| **Non-monotonic committer time** | Skewed or same-second main commits are caught for Play | `test_release_catches_committer_time_going_backwards`, `test_release_same_second_collision_is_refused` |
| **Release record** | `android-vc-*` tags on origin; local-only tags ignored | `test_record_then_next_main_commit_passes`, `test_unpushed_local_tag_does_not_count_but_remote_tag_does`, `test_record_refuses_lower_code_and_off_main` |
| **Gradle `versionCode` / pubspec** | `--build-number` overrides `+1`; `versionName` from pubspec; `--split-per-abi` refused | Wrapper tests assert `--build-number` equals the dart-define; `test_split_per_abi_is_refused`; `aapt dump badging` on the built APK |
| **Crashlytics keys** | `build_number` equals `versionCode`; `build_git_sha` unchanged | Same |
| **Force-update** | Uses `versionName`; unaffected, but `versionName` must be bumped per release | Docs |
| **Release process** | Prod config must be committed to `main`; build from a clean `origin/main` checkout; record the tag after upload | `operations.md`, `mobile-prod-flavor-and-crashlytics.md` |
| **All build paths** | No tracked script, doc or config may build an APK or AAB with Flutter or Gradle directly | `test_every_android_build_path_uses_a_wrapper` |
| **iOS** | Not wired to wrappers yet | N/A |

## Regression test

| Item | Detail |
|------|--------|
| **Test added** | `scripts/tests/test_android_version_code.py` (squash simulation, derivation, release guard, record, wrapper routing) |
| **Fails on old code** | Run against `origin/main`'s `build_stamp.sh` (`rev-list --count`): squash test fails `assert 3 >= 4` |
| **Passes with fix** | `main` after squash > branch tip; guard catches every non-monotonic case above |

## References

- GitHub #444
- `apps/mobile/scripts/derive_android_version_code.sh`, `android_release_guard.sh`, `record_android_release.sh`, `build_stamp.sh`, `flutter_build_stamp.sh`, `flutter_build_apk.sh`, `flutter_build_appbundle.sh`
- `scripts/tests/test_android_version_code.py`, `scripts/tests/test_flutter_build_apk_script.py`
