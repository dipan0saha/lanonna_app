# Contributing

Thank you for helping improve La Nonna. This is a **public** repository: never commit passwords, API keys, personal email addresses, or Firebase UIDs.

## Before you open a PR

1. Read [docs/engineering/change-safety.md](docs/engineering/change-safety.md) — local pre-merge gate, impact analysis, and regression-test rules.
2. Run the gate from the repo root:
   - `./scripts/premerge_check.sh` (full; required before merge)
   - `./scripts/premerge_check.sh --e2e` when the change touches mobile user flows covered by Maestro P0
3. Paste `premerge-report.md` into the PR description after a green run.
4. For bug fixes, include impact analysis and name the regression test that fails on `origin/main` without your change.

## Development setup

See [docs/engineering/development.md](docs/engineering/development.md) for Flutter, API, worker, Postgres, and deploy workflows.

## RCA / postmortems

Use [docs/engineering/rca/TEMPLATE.md](docs/engineering/rca/TEMPLATE.md) for new write-ups under `docs/engineering/rca/`.
