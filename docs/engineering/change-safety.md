# Change safety (local pre-merge)

GitHub Actions CI was removed from this repository. **All merge gates run locally** on a developer Mac before opening or merging a pull request.

## Pre-merge gate

From the repo root:

```bash
./scripts/premerge_check.sh              # full gate (required before merge)
./scripts/premerge_check.sh --fast       # quick iteration while coding
./scripts/premerge_check.sh --e2e        # full gate + Maestro P0 on emulator-5554
```

The script writes `premerge-report.md` (step table with pass/fail, test counts, coverage percentages and timings; no secrets). **Paste that report into the PR body** after a green full run. It exits non-zero when any step fails, and an aborted run is reported as FAIL, never PASS.

### Full gate (`./scripts/premerge_check.sh`)

| Step | What it runs |
|------|----------------|
| Toolchain | `git fetch`, Flutter **3.38.9**, Python **3.12** venv in `.cache/premerge-venv` (API, worker and `scripts/premerge-requirements.txt`; rebuilt only when requirement files change) |
| Repo guards | `scripts/verify-no-personal-emails.sh`, `scripts/tests` (migration script unit tests) |
| Mobile static | `flutter pub get`, `flutter gen-l10n` + clean `lib/l10n/` diff, chip guard, raw `RefreshIndicator` guard, hardcoded user-string guard, `flutter analyze --no-fatal-infos` |
| `lanonna_activity_copy` | `pytest packages/lanonna_activity_copy/tests` |
| API | `pytest services/api/tests` (unit + Postgres integration, incl. FK index coverage test) with coverage XML |
| Worker | `pytest services/worker/tests` (unit + Postgres integration) with coverage XML |
| Mobile tests | `flutter test --coverage --exclude-tags golden` |
| Diff coverage | `diff-cover` vs `origin/main` at **80%** of changed lines, separately for `services/api/src`, `services/worker/src` and `apps/mobile/lib` (generated l10n, `*.g.dart`, `*.freezed.dart` excluded). Reformatted lines count as changed. |
| Optional `--e2e` | `apps/mobile/maestro/scripts/run-maestro-p0.sh` |

Python: the gate needs a 3.12 interpreter (production images use `python:3.12-slim`). It uses `python3.12` on `PATH`, else `uv python find 3.12`; install with `brew install python@3.12` or `uv python install 3.12`, or set `PREMERGE_PYTHON_BIN`.

Postgres: if nothing is listening on `127.0.0.1:5432`, the gate starts a throwaway **Postgres 16** cluster in a temp directory (`brew install postgresql@16`, or set `PREMERGE_PG_BIN`), falling back to `docker compose -f docker-compose.test.yml` when Docker is installed, and stops it when the run ends (`--keep-postgres` leaves it up). An existing server on `127.0.0.1:5432` with user/password `postgres` is reused and left alone. Integration fixtures apply `infra/db/migrations/`.

### Fast mode (`--fast`)

Skips Postgres integration tests, coverage collection, and diff-coverage. Still runs guards, analyze, and unit tests. Use while iterating; **do not merge** on fast mode alone.

### Maestro P0 (`--e2e`)

Runs only when every other step passed. Requires Maestro CLI, a booted `adb` device `emulator-5554`, `apps/mobile/maestro/local.env` (gitignored; QA test accounts only), the Cloud SQL Auth Proxy for `lanonna-dev` on `127.0.0.1:5433` (fixtures), Firebase/gcloud credentials, and a Python with `psycopg` + `firebase-admin` (`infra/db/.venv`). It builds and installs the debug APK, runs the flows, and fails the gate if any flow fails. See [apps/mobile/maestro/README.md](../../apps/mobile/maestro/README.md) and [maestro/flows/p0/COVERAGE.md](../../apps/mobile/maestro/flows/p0/COVERAGE.md).

## Removed GitHub Actions → local mapping

| Former CI (`ci.yml`) | Local replacement |
|----------------------|-------------------|
| **Job `api`**: Python 3.12 venv, `packages/lanonna_activity_copy/tests` | `premerge_check.sh` → Package step |
| **Job `api`**: `pytest services/api/tests` vs Postgres 16 service | Full mode → API pytest (integration) against the throwaway Postgres 16 |
| **Job `api`**: `scripts/verify-no-personal-emails.sh` | Guard step |
| **Job `worker`**: worker `pytest` vs Postgres 16 | Full mode → Worker pytest (integration) |
| **Job `mobile`**: `flutter pub get`, `gen-l10n` freshness | Mobile static → gen-l10n step |
| **Job `mobile`**: `check-no-material-chips.sh` | Mobile static |
| **Job `mobile`**: `check-no-raw-refresh-indicator.sh` | Mobile static |
| **Job `mobile`**: `check_hardcoded_user_strings.dart` | Mobile static |
| **Job `mobile`**: `flutter analyze --no-fatal-infos` | Mobile static |
| **Job `mobile`**: `flutter test --exclude-tags golden` | Mobile tests (with `--coverage` in full mode) |
| *(not in CI)* | `scripts/tests`, diff-coverage 80%, optional Maestro P0 |

`.github/workflows/ci.yml` was the only file under `.github/`, so the directory is gone. No branch protection or required checks depend on it.

## PR checklist

One concern per PR.

1. **Impact analysis** — fill the [RCA Impact analysis](rca/TEMPLATE.md#impact-analysis) section (or equivalent in the PR) listing callers, screens, endpoints, and user flows touched, and which test or Maestro flow covers each. **Gaps need a test before the fix merges.**
2. **Regression test** — every bug fix adds a test (unit, integration, or Maestro) that **fails on `origin/main`** without the fix. Prove with: check out `origin/main`, run only the new test, confirm failure; apply the fix, confirm pass.
3. **Pre-merge gate** — `./scripts/premerge_check.sh` full pass; for user-facing flows also `./scripts/premerge_check.sh --e2e`. Attach `premerge-report.md` to the PR.
4. **Post-deploy (dev)** — deploy per [development.md](development.md), run `./scripts/verify-migrations.sh` when schema changed, smoke the affected flow on `lanonna-dev`, and check Crashlytics for new fatals.

## Related docs

- [development.md](development.md) — automated tests, Postgres, Flutter pins
- [docs/qa/pre-prod-test-plan.md](../qa/pre-prod-test-plan.md) — manual P0 catalog
- [CONTRIBUTING.md](../../CONTRIBUTING.md) — contributor entry point
