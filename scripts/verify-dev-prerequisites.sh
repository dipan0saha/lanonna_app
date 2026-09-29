#!/usr/bin/env bash
# Exit 0 when dev platform prerequisites pass (for "ready to build product" gate).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

API_BASE="${API_BASE_URL:-https://api-1008830071001.us-central1.run.app}"
PROJECT="${GCP_PROJECT_ID:-lanonna-dev}"
FAIL=0

step() { echo ""; echo "== $*"; }

step "Terraform validate"
(
  cd infra/terraform/environments/dev
  terraform init -input=false >/dev/null
  terraform validate
)

step "Cloud Run worker IAM (Pub/Sub OIDC)"
"${ROOT}/scripts/apply-dev-run-iam.sh"

step "API /health"
HEALTH="$(curl -fsS "${API_BASE}/health")"
echo "${HEALTH}"
echo "${HEALTH}" | grep -q '"status":"ok"' || FAIL=1

step "Flutter analyze + test"
(
  cd apps/mobile
  flutter pub get
  flutter analyze
  flutter test
)

step "API / worker compile check"
PY="${LANONNA_PYTHON:-}"
if [[ -z "${PY}" ]]; then
  for c in python3.12 python3.11 python3; do
    if command -v "${c}" >/dev/null; then PY="${c}"; break; fi
  done
fi
VENV="/tmp/lanonna-api-venv"
"${PY}" -m venv "${VENV}"
"${VENV}/bin/pip" install -q -r services/api/requirements.txt
PYTHONPATH=services/api/src "${VENV}/bin/python" -m compileall -q services/api/src
"${VENV}/bin/pip" install -q -r services/worker/requirements.txt
PYTHONPATH=services/worker/src "${VENV}/bin/python" -m compileall -q services/worker/src

if [[ -n "${SMOKE_TEST_PASSWORD:-}" ]]; then
  step "Display upload smoke (GCS → Pub/Sub → worker)"
  "${ROOT}/scripts/infra-smoke-display-upload.sh"
else
  echo "SKIP upload smoke (set SMOKE_TEST_PASSWORD to run)"
fi

step "Worker public invoker (should be absent)"
if gcloud run services get-iam-policy worker --region=us-central1 --project="${PROJECT}" --format=json 2>/dev/null \
  | grep -q 'allUsers'; then
  echo "FAIL: worker still has allUsers run.invoker — remove before prod (see docs/building-the-app.md)"
  FAIL=1
else
  echo "OK: no allUsers on worker"
fi

if [[ "${FAIL}" -ne 0 ]]; then
  echo ""
  echo "One or more checks failed."
  exit 1
fi

echo ""
echo "All prerequisite checks passed."
