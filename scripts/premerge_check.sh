#!/usr/bin/env bash
# Local pre-merge quality gate (replaces removed GitHub Actions CI).
#
# Usage (from repo root):
#   ./scripts/premerge_check.sh              # full gate (required before merge)
#   ./scripts/premerge_check.sh --fast       # quick iteration (no diff-coverage, unit tests only)
#   ./scripts/premerge_check.sh --e2e        # full gate + Maestro P0 suite on emulator-5554
#
# Options:
#   --fast                 Skip diff-coverage and Postgres integration tests
#   --e2e                  After static/unit checks, run apps/mobile/maestro P0 flows
#   --diff-threshold N     Diff coverage minimum (default: 80)
#   --compare-branch REF   Merge base for diff coverage (default: origin/main)
#   --report PATH          Write summary report (default: premerge-report.md in repo root)
#   --keep-postgres        Do not stop docker-compose.test.yml postgres after run
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

FAST=0
E2E=0
DIFF_THRESHOLD=80
COMPARE_BRANCH="origin/main"
REPORT="${ROOT}/premerge-report.md"
KEEP_POSTGRES=0
STARTED_POSTGRES=0
VENV="${ROOT}/.cache/premerge-venv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast) FAST=1; shift ;;
    --e2e) E2E=1; shift ;;
    --diff-threshold) DIFF_THRESHOLD="$2"; shift 2 ;;
    --compare-branch) COMPARE_BRANCH="$2"; shift 2 ;;
    --report) REPORT="$2"; shift 2 ;;
    --keep-postgres) KEEP_POSTGRES=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

declare -a STEP_NAMES=()
declare -a STEP_STATUS=()
declare -a STEP_NOTES=()
FAILURES=0

log() { printf '%s\n' "$*"; }

record_step() {
  local name="$1" status="$2" note="${3:-}"
  STEP_NAMES+=("$name")
  STEP_STATUS+=("$status")
  STEP_NOTES+=("$note")
  if [[ "$status" != "PASS" ]]; then
    FAILURES=$((FAILURES + 1))
  fi
}

run_step() {
  local name="$1"
  shift
  log ""
  log "== ${name}"
  if "$@"; then
    record_step "$name" "PASS"
    return 0
  fi
  record_step "$name" "FAIL" "see log above"
  return 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing prerequisite command: $1"
    return 1
  fi
  return 0
}

check_flutter_version() {
  local expected="3.38.9"
  local line
  line="$(flutter --version 2>/dev/null | head -n1 || true)"
  if [[ -z "$line" ]]; then
    log "flutter not found or --version failed"
    return 1
  fi
  if [[ "$line" != *"${expected}"* ]]; then
    log "Expected Flutter ${expected}; got: ${line}"
    log "Install the pinned SDK (see docs/engineering/development.md)."
    return 1
  fi
  return 0
}

ensure_python_venv() {
  local py=""
  for c in python3.12 python3; do
    if command -v "$c" >/dev/null 2>&1; then
      py="$c"
      break
    fi
  done
  if [[ -z "$py" ]]; then
    log "python3.12 or python3 required"
    return 1
  fi
  if [[ ! -x "${VENV}/bin/python" ]]; then
    mkdir -p "$(dirname "${VENV}")"
    "${py}" -m venv "${VENV}"
    "${VENV}/bin/pip" install -q --upgrade pip
    "${VENV}/bin/pip" install -q \
      -r services/api/requirements.txt \
      -r services/api/requirements-dev.txt \
      -r services/worker/requirements.txt
    "${VENV}/bin/pip" install -q -e packages/lanonna_activity_copy -e services/api
    "${VENV}/bin/pip" install -q pytest-cov diff-cover
  fi
  export PREMERGE_PYTHON="${VENV}/bin/python"
  export PREMERGE_PYTEST="${VENV}/bin/pytest"
  return 0
}

postgres_ready() {
  if command -v pg_isready >/dev/null 2>&1; then
    pg_isready -h 127.0.0.1 -p 5432 -U postgres >/dev/null 2>&1
    return $?
  fi
  return 1
}

ensure_postgres() {
  if postgres_ready; then
    log "Postgres already accepting connections on 127.0.0.1:5432"
    return 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    log "Postgres not reachable and docker not installed."
    log "Start Postgres 16 on 127.0.0.1:5432 (user/password postgres) or install Docker."
    return 1
  fi
  if ! docker compose -f docker-compose.test.yml up -d --wait 2>/dev/null; then
    docker compose -f docker-compose.test.yml up -d
    local i
    for i in $(seq 1 30); do
      if postgres_ready; then
        STARTED_POSTGRES=1
        return 0
      fi
      sleep 2
    done
    log "Timed out waiting for docker-compose.test.yml postgres"
    return 1
  fi
  STARTED_POSTGRES=1
  return 0
}

stop_postgres_if_started() {
  if [[ "${KEEP_POSTGRES}" -eq 1 || "${STARTED_POSTGRES}" -eq 0 ]]; then
    return 0
  fi
  docker compose -f docker-compose.test.yml down >/dev/null 2>&1 || true
}

write_report() {
  local mode="full"
  [[ "${FAST}" -eq 1 ]] && mode="fast"
  {
    echo "# Pre-merge check report"
    echo ""
    echo "| Field | Value |"
    echo "|-------|-------|"
    echo "| Mode | \`${mode}\` |"
    echo "| Compare branch | \`${COMPARE_BRANCH}\` |"
    echo "| Diff threshold | ${DIFF_THRESHOLD}% (full mode only) |"
    echo "| E2E | $( [[ "${E2E}" -eq 1 ]] && echo yes || echo no ) |"
    echo "| Result | $( [[ "${FAILURES}" -eq 0 ]] && echo **PASS** || echo **FAIL** ) |"
    echo ""
    echo "## Steps"
    echo ""
    echo "| Step | Status | Notes |"
    echo "|------|--------|-------|"
    local i
    for i in "${!STEP_NAMES[@]}"; do
      echo "| ${STEP_NAMES[$i]} | ${STEP_STATUS[$i]} | ${STEP_NOTES[$i]} |"
    done
    echo ""
    echo "Re-run from repo root: \`./scripts/premerge_check.sh$( [[ "${FAST}" -eq 1 ]] && echo ' --fast' )$( [[ "${E2E}" -eq 1 ]] && echo ' --e2e' )\`"
    echo ""
    echo "_Generated by scripts/premerge_check.sh — paste into PR description (no secrets)._"
  } >"${REPORT}"
}

# --- prerequisites ---
if ! run_step "Prerequisites: git" require_cmd git; then :; fi
if ! run_step "Prerequisites: flutter" require_cmd flutter; then :; fi
if [[ "${FAST}" -eq 0 ]]; then
  run_step "Prerequisites: docker or local Postgres" bash -c '
    command -v docker >/dev/null 2>&1 || command -v pg_isready >/dev/null 2>&1
  ' || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Fetch compare branch (${COMPARE_BRANCH})" git fetch origin "${COMPARE_BRANCH#origin/}" --quiet || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Flutter SDK version (3.38.9)" check_flutter_version || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Python venv + test tools" ensure_python_venv || true
fi

# --- repo guards (formerly CI api job + mobile job) ---
if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Guard: no personal email domains" bash scripts/verify-no-personal-emails.sh || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Scripts: verify-migrations shell tests" "${PREMERGE_PYTHON}" -m pytest -q scripts/tests || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Mobile: pub get + gen-l10n freshness" bash -c '
    cd apps/mobile
    flutter pub get
    flutter gen-l10n
    git diff --exit-code -- lib/l10n/ || {
      echo "Generated l10n is stale: run flutter gen-l10n and commit lib/l10n/"
      exit 1
    }
  ' || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Mobile: check-no-material-chips.sh" bash -c 'cd apps/mobile && bash scripts/check-no-material-chips.sh' || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Mobile: check-no-raw-refresh-indicator.sh" bash -c 'cd apps/mobile && bash scripts/check-no-raw-refresh-indicator.sh' || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Mobile: hardcoded user strings guard" bash -c 'cd apps/mobile && dart run tool/check_hardcoded_user_strings.dart .' || true
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  run_step "Mobile: flutter analyze --no-fatal-infos" bash -c 'cd apps/mobile && flutter analyze --no-fatal-infos' || true
fi

# --- tests ---
if [[ "${FAILURES}" -eq 0 ]]; then
  if [[ "${FAST}" -eq 1 ]]; then
    run_step "Package: lanonna_activity_copy tests" \
      "${PREMERGE_PYTEST}" -q packages/lanonna_activity_copy/tests || true
  else
    run_step "Package: lanonna_activity_copy tests" \
      "${PREMERGE_PYTEST}" -q packages/lanonna_activity_copy/tests || true
  fi
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  if [[ "${FAST}" -eq 1 ]]; then
    run_step "API: pytest (unit only, no integration)" bash -c \
      'PYTHONPATH=services/api/src "${PREMERGE_PYTEST}" -q services/api/tests -m "not integration"' || true
  else
    run_step "Postgres 16 for integration tests" ensure_postgres || true
    if [[ "${FAILURES}" -eq 0 ]]; then
      run_step "API: pytest (unit + integration, with coverage)" bash -c \
        'PYTHONPATH=services/api/src "${PREMERGE_PYTEST}" -q services/api/tests \
          --cov=lanonna_api --cov-report=xml:"${ROOT}/coverage-api.xml"' || true
    fi
  fi
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  if [[ "${FAST}" -eq 1 ]]; then
    run_step "Worker: pytest (unit only)" bash -c \
      'cd services/worker && PYTHONPATH=src "${PREMERGE_PYTEST}" -q tests -m "not integration"' || true
  else
    if [[ "${STARTED_POSTGRES}" -eq 1 ]] || postgres_ready; then
      run_step "Worker: pytest (unit + integration, with coverage)" bash -c \
        'cd services/worker && PYTHONPATH=src "${PREMERGE_PYTEST}" -q tests \
          --cov=lanonna_worker --cov-report=xml:"${ROOT}/coverage-worker.xml"' || true
    else
      record_step "Worker: pytest (unit + integration)" "FAIL" "Postgres unavailable"
      FAILURES=$((FAILURES + 1))
    fi
  fi
fi

if [[ "${FAILURES}" -eq 0 ]]; then
  if [[ "${FAST}" -eq 1 ]]; then
    run_step "Mobile: flutter test --exclude-tags golden" bash -c \
      'cd apps/mobile && flutter test --exclude-tags golden' || true
  else
    run_step "Mobile: flutter test --coverage --exclude-tags golden" bash -c \
      'cd apps/mobile && flutter test --coverage --exclude-tags golden' || true
  fi
fi

# --- diff coverage (full mode) ---
if [[ "${FAILURES}" -eq 0 && "${FAST}" -eq 0 ]]; then
  if ! git rev-parse --verify "${COMPARE_BRANCH}" >/dev/null 2>&1; then
    record_step "Diff coverage (${DIFF_THRESHOLD}%)" "FAIL" "missing ${COMPARE_BRANCH}; git fetch origin main"
    FAILURES=$((FAILURES + 1))
  else
    run_step "Diff coverage: API (pytest-cov + diff-cover)" bash -c \
      '"${VENV}/bin/diff-cover" "${ROOT}/coverage-api.xml" \
        --compare-branch "${COMPARE_BRANCH}" --fail-under "${DIFF_THRESHOLD}"' || true
    if [[ "${FAILURES}" -eq 0 ]]; then
      run_step "Diff coverage: worker" bash -c \
        '"${VENV}/bin/diff-cover" "${ROOT}/coverage-worker.xml" \
          --compare-branch "${COMPARE_BRANCH}" --fail-under "${DIFF_THRESHOLD}"' || true
    fi
    if [[ "${FAILURES}" -eq 0 ]]; then
      run_step "Diff coverage: mobile (lcov)" bash -c \
        '"${VENV}/bin/diff-cover" apps/mobile/coverage/lcov.info --format=lcov \
          --compare-branch "${COMPARE_BRANCH}" --fail-under "${DIFF_THRESHOLD}"' || true
    fi
  fi
fi

# --- optional Maestro P0 ---
if [[ "${E2E}" -eq 1 && "${FAILURES}" -eq 0 ]]; then
  run_step "Maestro P0 suite (--e2e)" bash -c 'cd apps/mobile && ./maestro/scripts/run-maestro-p0.sh' || true
fi

stop_postgres_if_started
write_report

log ""
if [[ "${FAILURES}" -eq 0 ]]; then
  log "Pre-merge check PASSED. Report: ${REPORT}"
  exit 0
fi

log "Pre-merge check FAILED (${FAILURES} step(s)). Report: ${REPORT}"
exit 1
