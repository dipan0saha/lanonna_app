#!/usr/bin/env bash
# Beta gate helper: deploy API (incl. COMMENTS notify channel + app version route), run tests.
# App Check: keep APP_CHECK_ENFORCE=false until debug tokens registered; then:
#   APP_CHECK_ENFORCE=true ./services/api/scripts/deploy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

echo "== API + worker unit tests =="
PYTHONPATH=services/api/src services/api/.venv/bin/python -m pytest -q services/api/tests
PYTHONPATH=services/worker/src services/api/.venv/bin/python -m pytest -q services/worker/tests

echo "== Flutter tests =="
(cd apps/mobile && flutter test)

echo "== Deploy API to lanonna-dev (optional; requires gcloud) =="
if command -v gcloud >/dev/null 2>&1; then
  "${ROOT}/services/api/scripts/deploy.sh"
  echo "After deploy: apply migration 020 on dev SQL if not yet applied:"
  echo "  DB_PORT=5433 DB_PASSWORD=… python infra/db/apply_migrations.py"
  echo "Pre-beta manual QA: docs/engineering/pre-beta-qa.md"
else
  echo "gcloud not found — skip deploy; run services/api/scripts/deploy.sh locally."
fi
