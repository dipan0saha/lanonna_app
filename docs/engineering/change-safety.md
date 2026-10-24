# Change safety (local pre-merge)

GitHub Actions CI was removed from this repository. **All merge gates run locally** on a developer Mac before opening or merging a pull request.

## Pre-merge gate

From the repo root:

```bash
./scripts/premerge_check.sh              # full gate (required before merge)
./scripts/premerge_check.sh --fast       # quick iteration while coding
./scripts/premerge_check.sh --e2e        # full gate + Maestro P0 on emulator-5554
```

The script writes `premerge-report.md` (no secrets). **Paste that report into the PR body** after a green full run.

### Full gate (`./scripts/premerge_check.sh`)

| Step | What it runs |
|------|----------------|
| Toolchain | `git fetch`, Flutter **3.38.9**, Python 3.12 venv with `pytest-cov` and `diff-cover` |
| Repo guards | `scripts/verify-no-personal-emails.sh`, `scripts/tests` (migration script unit tests) |
| Mobile static | `flutter pub get`, `flutter gen-l10n` + clean `lib/l10n/` diff, chip guard, raw `RefreshIndicator` guard, hardcoded user-string guard, `flutter analyze --no-fatal-infos` |
| `lanonna_activity_copy` | `pytest packages/lanonna_activity_copy/tests` |
| API | `pytest services/api/tests` (unit + Postgres integration, incl. FK index coverage test) with coverage XML |
| Worker | `pytest services/worker/tests` (unit + Postgres integration) with coverage XML |
| Mobile tests | `flutter test --coverage --exclude-tags golden` |
| Diff coverage | `diff-cover` vs `origin/main` at **80%** on changed lines (API, worker, mobile lcov) |
| Optional `--e2e` | `apps/mobile/maestro/scripts/run-maestro-p0.sh` |

Postgres: throwaway **Postgres 16** via `docker compose -f docker-compose.test.yml up -d` (or any instance on `127.0.0.1:5432`, user/password `postgres`). Integration fixtures apply `infra/db/migrations/`.

### Fast mode (`--fast`)

Skips Postgres integration tests, coverage collection, and diff-coverage. Still runs guards, analyze, and unit tests. Use while iterating; **do not merge** on fast mode alone.

### Maestro P0 (`--e2e`)

Requires Maestro CLI, `adb` device `emulator-5554`, `apps/mobile/maestro/local.env` (gitignored), and dev API reachability. See [apps/mobile/maestro/README.md](../../apps/mobile/maestro/README.md) and [maestro/flows/p0/COVERAGE.md](../../apps/mobile/maestro/flows/p0/COVERAGE.md).

## Removed GitHub Actions → local mapping

| Former CI (`ci.yml`) | Local replacement |
|----------------------|-------------------|
| **Job `api`**: Python 3.12 venv, `packages/lanonna_activity_copy/tests` | `premerge_check.sh` → Package step |
| **Job `api`**: `pytest services/api/tests` vs Postgres 16 service | Full mode → API pytest (integration) after `docker-compose.test.yml` |
| **Job `api`**: `scripts/verify-no-personal-emails.sh` | Guard step |
| **Job `worker`**: worker `pytest` vs Postgres 16 | Full mode → Worker pytest (integration) |
| **Job `mobile`**: `flutter pub get`, `gen-l10n` freshness | Mobile static → gen-l10n step |
| **Job `mobile`**: `check-no-material-chips.sh` | Mobile static |
| **Job `mobile`**: `check-no-raw-refresh-indicator.sh` | Mobile static |
| **Job `mobile`**: `check_hardcoded_user_strings.dart` | Mobile static |
| **Job `mobile`**: `flutter analyze --no-fatal-infos` | Mobile static |
| **Job `mobile`**: `flutter test --exclude-tags golden` | Mobile tests (with `--coverage` in full mode) |
| *(not in CI)* | `scripts/tests`, diff-coverage 80%, optional Maestro P0 |

Other `.github/` assets (issue templates, etc.) are unchanged. Only workflow files were removed.

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
