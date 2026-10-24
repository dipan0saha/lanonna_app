#!/usr/bin/env bash
# Local pre-merge quality gate. GitHub Actions CI was removed on purpose: every
# check runs on the developer's machine and the report goes in the PR body.
#
# Usage (from anywhere in the repo):
#   ./scripts/premerge_check.sh              # full gate (required before merge)
#   ./scripts/premerge_check.sh --e2e        # full gate + Maestro P0 suite on emulator-5554
#   ./scripts/premerge_check.sh --fast       # quick iteration (no Postgres, no coverage)
#
# Options:
#   --fast                 Skip Postgres integration tests, coverage and diff-coverage
#   --e2e                  After all other steps pass, run apps/mobile/maestro P0 flows
#   --diff-threshold N     Diff coverage minimum on changed lines (default: 80)
#   --compare-branch REF   Base for diff coverage (default: origin/main)
#   --report PATH          Summary report (default: premerge-report.md in repo root)
#   --keep-postgres        Leave the Postgres this script started running
#   --keep-going           Run every step even after a failure (default: stop at first)
#
# Environment:
#   PREMERGE_PYTHON_BIN    Python 3.12 interpreter (default: python3.12, then `uv python find 3.12`)
#   PREMERGE_VENV          Venv location (default: <repo>/.cache/premerge-venv)
#   PREMERGE_PG_BIN        Postgres 16 bin dir (default: Homebrew postgresql@16)
#
# Exit status: 0 only when every step passed. Any failed step exits 1; bad usage exits 2.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

FAST=0
E2E=0
KEEP_GOING=0
DIFF_THRESHOLD=80
COMPARE_BRANCH="origin/main"
REPORT="${ROOT}/premerge-report.md"
KEEP_POSTGRES=0
VENV="${PREMERGE_VENV:-${ROOT}/.cache/premerge-venv}"
PY_VERSION_REQUIRED="3.12"
FLUTTER_VERSION_REQUIRED="3.38.9"
PG_PORT=5432

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast) FAST=1; shift ;;
    --e2e) E2E=1; shift ;;
    --keep-going) KEEP_GOING=1; shift ;;
    --diff-threshold) DIFF_THRESHOLD="${2:?--diff-threshold needs a value}"; shift 2 ;;
    --compare-branch) COMPARE_BRANCH="${2:?--compare-branch needs a value}"; shift 2 ;;
    --report) REPORT="${2:?--report needs a value}"; shift 2 ;;
    --keep-postgres) KEEP_POSTGRES=1; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
if [[ "${FAST}" -eq 1 && "${E2E}" -eq 1 ]]; then
  echo "--e2e runs on top of the full gate; do not combine it with --fast" >&2
  exit 2
fi
if ! [[ "${DIFF_THRESHOLD}" =~ ^[0-9]+$ ]] || (( DIFF_THRESHOLD > 100 )); then
  echo "--diff-threshold must be an integer 0-100" >&2
  exit 2
fi

LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lanonna-premerge.XXXXXX")"
PG_TMP=""
PG_BIN=""
STARTED_POSTGRES=""   # "", "native" or "docker"
GATE_START=${SECONDS}
STEP_INDEX=0
FAILURES=0
declare -a STEP_NAMES=() STEP_STATUS=() STEP_NOTES=() STEP_SECS=()

log() { printf '%s\n' "$*"; }

fmt_secs() { printf '%dm%02ds' $(( $1 / 60 )) $(( $1 % 60 )); }

record_step() {
  STEP_NAMES+=("$1"); STEP_STATUS+=("$2"); STEP_NOTES+=("${3:-}"); STEP_SECS+=("${4:-0}")
  if [[ "$2" == "FAIL" ]]; then FAILURES=$((FAILURES + 1)); fi
}

should_run() { [[ "${FAILURES}" -eq 0 || "${KEEP_GOING}" -eq 1 ]]; }

# One-line result summary pulled from a step log (test counts, coverage %).
summarize_log() {
  local raw="$1" f="$1.lines" s=""
  # flutter's compact reporter redraws one line with carriage returns.
  tr '\r' '\n' <"${raw}" >"${f}"
  s="$(grep -E '^=+ .*(passed|failed|error).* in [0-9.]+s' "$f" | tail -n1 | sed -E 's/^=+ //; s/ =+$//')" || true
  if [[ -z "$s" ]]; then
    s="$(grep -E '^[0-9]+ (passed|failed)' "$f" | tail -n1)" || true
  fi
  if [[ -z "$s" ]]; then
    # flutter test: "01:23 +750 ~3: All tests passed!" / "+740 -2: Some tests failed."
    s="$(grep -aE '^[0-9]+:[0-9]+ \+[0-9]+.*(All tests passed|Some tests failed)' "$f" | tail -n1 | sed -E 's/^[0-9:]+ //; s/[[:space:]]+$//')" || true
  fi
  if grep -qE '^Total: +[0-9]+ lines?' "$f"; then
    local total missing cov
    total="$(grep -E '^Total: ' "$f" | tail -n1 | sed -E 's/[^0-9]//g')"
    missing="$(grep -E '^Missing: ' "$f" | tail -n1 | sed -E 's/[^0-9]//g')"
    cov="$(grep -E '^Coverage: ' "$f" | tail -n1 | sed -E 's/^Coverage: //')"
    s="${cov} of ${total} changed lines (${missing} missing)"
  elif grep -q 'No lines with coverage information in this diff' "$f"; then
    s="no changed lines in scope"
  fi
  if [[ -z "$s" ]]; then
    s="$(grep -E '^P0 summary:' "$f" | tail -n1)" || true
  fi
  printf '%s' "$s" | tr '|' '/' | cut -c1-160
}

# Runs "$@" in a subshell with `set -e` really in force (bash ignores -e inside
# functions called from an `if`), tees output to a per-step log, records result.
run_step() {
  local name="$1"; shift
  STEP_INDEX=$((STEP_INDEX + 1))
  local logf="${LOG_DIR}/$(printf '%02d' "${STEP_INDEX}").log"
  local t0=${SECONDS} rc
  log ""
  log "== ${name}"
  set +e
  ( set -euo pipefail; "$@" ) 2>&1 | tee "${logf}"
  rc=${PIPESTATUS[0]}
  set -e
  local secs=$((SECONDS - t0)) note
  note="$(summarize_log "${logf}")"
  if [[ ${rc} -eq 0 ]]; then
    record_step "${name}" "PASS" "${note}" "${secs}"
  else
    record_step "${name}" "FAIL" "exit ${rc}${note:+; ${note}}" "${secs}"
    log "!! FAILED: ${name} (exit ${rc})"
  fi
}

skip_step() { record_step "$1" "SKIP" "$2" 0; }

# --- step bodies ---------------------------------------------------------------

check_prereqs() {
  local missing=0 c
  for c in git flutter dart; do
    command -v "$c" >/dev/null 2>&1 || { log "Missing prerequisite: $c"; missing=1; }
  done
  if [[ "${FAST}" -eq 0 ]] && ! pg_bin_dir >/dev/null && ! command -v docker >/dev/null 2>&1 \
      && ! postgres_ready; then
    log "Full mode needs Postgres 16: install postgresql@16 (Homebrew) or Docker,"
    log "or run any Postgres on 127.0.0.1:${PG_PORT} with user/password postgres."
    missing=1
  fi
  return "${missing}"
}

check_flutter_version() {
  local line
  line="$(flutter --version 2>/dev/null | head -n1)"
  log "${line}"
  if [[ "${line}" != *"Flutter ${FLUTTER_VERSION_REQUIRED} "* ]]; then
    log "Expected Flutter ${FLUTTER_VERSION_REQUIRED} (see docs/engineering/development.md)."
    return 1
  fi
}

find_python() {
  local c
  for c in "${PREMERGE_PYTHON_BIN:-}" python3.12; do
    [[ -n "$c" ]] && command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return 0; }
  done
  if command -v uv >/dev/null 2>&1; then
    uv python find "${PY_VERSION_REQUIRED}" 2>/dev/null && return 0
  fi
  return 1
}

requirements_stamp() {
  cat services/api/requirements.txt services/api/requirements-dev.txt \
    services/worker/requirements.txt scripts/premerge-requirements.txt \
    packages/lanonna_activity_copy/pyproject.toml services/api/pyproject.toml \
    | shasum -a 256 | cut -d' ' -f1
  printf '%s\n' "${ROOT}"
}

ensure_python_venv() {
  local py ver stamp
  if ! py="$(find_python)"; then
    log "Python ${PY_VERSION_REQUIRED} not found (matches the Cloud Run images)."
    log "Install it: 'uv python install ${PY_VERSION_REQUIRED}' or 'brew install python@${PY_VERSION_REQUIRED}',"
    log "or set PREMERGE_PYTHON_BIN."
    return 1
  fi
  ver="$("${py}" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  if [[ "${ver}" != "${PY_VERSION_REQUIRED}" ]]; then
    log "Python at ${py} is ${ver}; need ${PY_VERSION_REQUIRED}."
    return 1
  fi
  stamp="$(requirements_stamp)"
  if [[ -x "${VENV}/bin/python" && -f "${VENV}/.premerge-stamp" ]] \
      && [[ "$(cat "${VENV}/.premerge-stamp")" == "${stamp}" ]] \
      && [[ "$("${VENV}/bin/python" -c 'import sys; print("%d.%d" % sys.version_info[:2])')" == "${ver}" ]]; then
    log "Reusing ${VENV} (requirements unchanged)"
    return 0
  fi
  log "Creating ${VENV} with ${py} (${ver})"
  rm -rf "${VENV}"
  mkdir -p "$(dirname "${VENV}")"
  "${py}" -m venv "${VENV}"
  "${VENV}/bin/python" -m pip install -q --upgrade pip
  "${VENV}/bin/python" -m pip install -q \
    -r services/api/requirements.txt \
    -r services/api/requirements-dev.txt \
    -r services/worker/requirements.txt \
    -r scripts/premerge-requirements.txt
  "${VENV}/bin/python" -m pip install -q -e packages/lanonna_activity_copy -e services/api
  printf '%s' "${stamp}" >"${VENV}/.premerge-stamp"
}

mobile_l10n_fresh() {
  cd apps/mobile
  flutter pub get
  flutter gen-l10n
  if ! git diff --exit-code -- lib/l10n/; then
    log "Generated l10n is stale: run flutter gen-l10n and commit lib/l10n/"
    return 1
  fi
  if [[ -n "$(git ls-files --others --exclude-standard -- lib/l10n/)" ]]; then
    log "Untracked generated l10n files: run flutter gen-l10n and commit lib/l10n/"
    return 1
  fi
}

mobile_script() { cd apps/mobile; bash "scripts/$1"; }
mobile_strings_guard() { cd apps/mobile; dart run tool/check_hardcoded_user_strings.dart .; }
mobile_analyze() { cd apps/mobile; flutter analyze --no-fatal-infos; }

pytest_package() { "${VENV}/bin/python" -m pytest -q packages/lanonna_activity_copy/tests; }
pytest_scripts() { "${VENV}/bin/python" -m pytest -q scripts/tests; }

pytest_api() {
  if [[ "${FAST}" -eq 1 ]]; then
    PYTHONPATH=services/api/src "${VENV}/bin/python" -m pytest -q services/api/tests \
      --ignore=services/api/tests/integration
  else
    rm -f "${ROOT}/coverage-api.xml"
    COVERAGE_FILE="${LOG_DIR}/.coverage-api" PYTHONPATH=services/api/src \
      "${VENV}/bin/python" -m pytest -q services/api/tests \
      --cov=lanonna_api --cov-report=term:skip-covered --cov-report=xml:"${ROOT}/coverage-api.xml"
  fi
}

pytest_worker() {
  cd services/worker
  if [[ "${FAST}" -eq 1 ]]; then
    PYTHONPATH=src "${VENV}/bin/python" -m pytest -q tests --ignore=tests/integration
  else
    rm -f "${ROOT}/coverage-worker.xml"
    COVERAGE_FILE="${LOG_DIR}/.coverage-worker" PYTHONPATH=src \
      "${VENV}/bin/python" -m pytest -q tests \
      --cov=lanonna_worker --cov-report=term:skip-covered --cov-report=xml:"${ROOT}/coverage-worker.xml"
  fi
}

flutter_tests() {
  cd apps/mobile
  if [[ "${FAST}" -eq 1 ]]; then
    flutter test --exclude-tags golden
    return
  fi
  rm -f coverage/lcov.info "${ROOT}/coverage-mobile.lcov"
  flutter test --coverage --exclude-tags golden
  # lcov SF paths are relative to apps/mobile; diff-cover matches repo-relative
  # git paths, so rewrite them or every Dart line would silently be out of scope.
  sed -E 's#^SF:(\./)?lib/#SF:apps/mobile/lib/#' coverage/lcov.info >"${ROOT}/coverage-mobile.lcov"
  if ! grep -q '^SF:apps/mobile/lib/' "${ROOT}/coverage-mobile.lcov"; then
    log "coverage/lcov.info has no lib/ entries; cannot measure Dart diff coverage"
    return 1
  fi
}

diff_cover() {
  local report="$1"; shift
  if [[ ! -s "${report}" ]]; then
    log "Missing coverage report ${report}"
    return 1
  fi
  "${VENV}/bin/diff-cover" "${report}" --compare-branch="${COMPARE_BRANCH}" \
    --fail-under="${DIFF_THRESHOLD}" "$@"
}

diff_cover_api() { diff_cover "${ROOT}/coverage-api.xml" --include 'services/api/src/*'; }
diff_cover_worker() { diff_cover "${ROOT}/coverage-worker.xml" --include 'services/worker/src/*'; }
diff_cover_mobile() {
  # Generated code is excluded: l10n freshness is its own step, codegen is not hand-written.
  diff_cover "${ROOT}/coverage-mobile.lcov" --format lcov \
    --include 'apps/mobile/lib/*' \
    --exclude 'apps/mobile/lib/l10n/*' '*.g.dart' '*.freezed.dart'
}

maestro_p0() { cd apps/mobile; ./maestro/scripts/run-maestro-p0.sh; }

# --- Postgres ------------------------------------------------------------------

pg_bin_dir() {
  local d
  for d in "${PREMERGE_PG_BIN:-}" /opt/homebrew/opt/postgresql@16/bin /usr/local/opt/postgresql@16/bin \
      /usr/lib/postgresql/16/bin; do
    [[ -n "$d" && -x "$d/pg_ctl" && -x "$d/initdb" && -x "$d/postgres" ]] && { printf '%s' "$d"; return 0; }
  done
  return 1
}

postgres_ready() {
  local isready
  isready="$(command -v pg_isready || true)"
  [[ -z "${isready}" && -n "$(pg_bin_dir || true)" ]] && isready="$(pg_bin_dir)/pg_isready"
  [[ -n "${isready}" ]] && "${isready}" -q -h 127.0.0.1 -p "${PG_PORT}" -U postgres
}

# Not run through run_step: it must set STARTED_POSTGRES in this shell so cleanup can stop it.
ensure_postgres() {
  if postgres_ready; then
    log "Using the Postgres already on 127.0.0.1:${PG_PORT} (user/password postgres expected)"
    return 0
  fi
  if PG_BIN="$(pg_bin_dir)"; then
    PG_TMP="$(mktemp -d "${TMPDIR:-/tmp}/lanonna-premerge-pg.XXXXXX")"
    printf 'postgres\n' >"${PG_TMP}/pwfile"
    log "Starting throwaway Postgres 16 from ${PG_BIN} in ${PG_TMP}"
    if ! "${PG_BIN}/initdb" -D "${PG_TMP}/data" -U postgres --pwfile="${PG_TMP}/pwfile" \
        -A scram-sha-256 -E UTF8 --no-locale >"${PG_TMP}/initdb.log" 2>&1; then
      cat "${PG_TMP}/initdb.log"; return 1
    fi
    STARTED_POSTGRES="native"
    if ! "${PG_BIN}/pg_ctl" -D "${PG_TMP}/data" -l "${PG_TMP}/postgres.log" -w -t 60 \
        -o "-p ${PG_PORT} -k ${PG_TMP} -c listen_addresses=127.0.0.1 -c fsync=off -c full_page_writes=off -c max_connections=200" \
        start >/dev/null; then
      tail -n 30 "${PG_TMP}/postgres.log" || true
      return 1
    fi
    "${PG_BIN}/postgres" --version
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    log "Starting docker-compose.test.yml Postgres 16"
    STARTED_POSTGRES="docker"
    docker compose -f docker-compose.test.yml up -d --wait || return 1
    return 0
  fi
  log "No Postgres 16 available (Homebrew postgresql@16, Docker, or a running server)."
  return 1
}

stop_postgres() {
  case "${STARTED_POSTGRES}" in
    native)
      if [[ "${KEEP_POSTGRES}" -eq 1 ]]; then
        log "Leaving Postgres running: ${PG_BIN}/pg_ctl -D ${PG_TMP}/data stop"
      else
        "${PG_BIN}/pg_ctl" -D "${PG_TMP}/data" -m fast -w stop >/dev/null 2>&1 || true
        rm -rf "${PG_TMP}"
      fi ;;
    docker)
      [[ "${KEEP_POSTGRES}" -eq 1 ]] || docker compose -f docker-compose.test.yml down >/dev/null 2>&1 || true ;;
  esac
  STARTED_POSTGRES=""
}

# --- report --------------------------------------------------------------------

write_report() {
  local mode="full" result="PASS" total=$((SECONDS - GATE_START)) i
  [[ "${FAST}" -eq 1 ]] && mode="fast"
  [[ "${E2E}" -eq 1 ]] && mode="full + e2e"
  [[ "${FAILURES}" -eq 0 ]] || result="FAIL"
  {
    echo "## Pre-merge gate report"
    echo ""
    echo "| Field | Value |"
    echo "|-------|-------|"
    echo "| Result | **${result}** |"
    echo "| Mode | ${mode} |"
    echo "| Commit | \`$(git rev-parse --short HEAD)\`$(git diff --quiet HEAD -- 2>/dev/null || echo ' + uncommitted changes') |"
    echo "| Compared with | \`${COMPARE_BRANCH}\` (\`$(git rev-parse --short "${COMPARE_BRANCH}" 2>/dev/null || echo '?')\`) |"
    echo "| Diff coverage minimum | ${DIFF_THRESHOLD}% of changed lines$( [[ "${FAST}" -eq 1 ]] && echo ' (not checked in fast mode)') |"
    echo "| Duration | $(fmt_secs "${total}") |"
    echo ""
    echo "| # | Step | Status | Time | Result |"
    echo "|---|------|--------|------|--------|"
    for i in "${!STEP_NAMES[@]}"; do
      echo "| $((i + 1)) | ${STEP_NAMES[$i]} | ${STEP_STATUS[$i]} | $(fmt_secs "${STEP_SECS[$i]}") | ${STEP_NOTES[$i]} |"
    done
    echo ""
    echo "_Generated by \`scripts/premerge_check.sh\`. Contains counts only, no secrets._"
  } >"${REPORT}"
}

GATE_FINISHED=0
cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  # An unexpected abort (syntax error, unbound variable outside a step) can leave
  # $? at 0. Never report PASS unless the gate reached its final verdict.
  if [[ "${GATE_FINISHED}" -ne 1 ]]; then
    [[ "${rc}" -ne 0 ]] || rc=1
    record_step "Gate run" "FAIL" "aborted before finishing" 0 || true
    log "Pre-merge check ABORTED (exit ${rc}); see output above."
  fi
  stop_postgres
  if [[ ${#STEP_NAMES[@]} -gt 0 ]]; then
    write_report || true
  fi
  rm -rf "${LOG_DIR}"
  exit "${rc}"
}
trap cleanup EXIT
trap 'log "Interrupted"; FAILURES=$((FAILURES + 1)); exit 130' INT TERM

# --- gate ----------------------------------------------------------------------

run_step "Prerequisites" check_prereqs
should_run && run_step "Fetch ${COMPARE_BRANCH}" git fetch --quiet origin "${COMPARE_BRANCH#origin/}"
should_run && run_step "Flutter SDK ${FLUTTER_VERSION_REQUIRED}" check_flutter_version
should_run && run_step "Python ${PY_VERSION_REQUIRED} venv + test tools" ensure_python_venv

# Former CI job "api": repo guard
should_run && run_step "Guard: no personal email domains" bash scripts/verify-no-personal-emails.sh
should_run && run_step "Scripts: scripts/tests" pytest_scripts

# Former CI job "mobile"
should_run && run_step "Mobile: pub get + gen-l10n freshness" mobile_l10n_fresh
should_run && run_step "Mobile: no Material chips guard" mobile_script check-no-material-chips.sh
should_run && run_step "Mobile: no raw RefreshIndicator guard" mobile_script check-no-raw-refresh-indicator.sh
should_run && run_step "Mobile: hardcoded user strings guard" mobile_strings_guard
should_run && run_step "Mobile: flutter analyze --no-fatal-infos" mobile_analyze

# Former CI jobs "api" and "worker": tests
should_run && run_step "Package: lanonna_activity_copy tests" pytest_package
if should_run && [[ "${FAST}" -eq 0 ]]; then
  STEP_INDEX=$((STEP_INDEX + 1)); t0=${SECONDS}
  log ""; log "== Postgres 16 for integration tests"
  if ensure_postgres; then
    record_step "Postgres 16 for integration tests" "PASS" "${STARTED_POSTGRES:-existing server}" $((SECONDS - t0))
  else
    record_step "Postgres 16 for integration tests" "FAIL" "not available" $((SECONDS - t0))
  fi
fi
if [[ "${FAST}" -eq 1 ]]; then
  should_run && run_step "API: pytest (unit only)" pytest_api
  should_run && run_step "Worker: pytest (unit only)" pytest_worker
else
  should_run && run_step "API: pytest unit + Postgres integration (coverage)" pytest_api
  should_run && run_step "Worker: pytest unit + Postgres integration (coverage)" pytest_worker
fi
stop_postgres

should_run && run_step "Mobile: flutter test$( [[ "${FAST}" -eq 0 ]] && echo ' --coverage') --exclude-tags golden" flutter_tests

if [[ "${FAST}" -eq 0 ]]; then
  should_run && run_step "Diff coverage ${DIFF_THRESHOLD}%: API" diff_cover_api
  should_run && run_step "Diff coverage ${DIFF_THRESHOLD}%: worker" diff_cover_worker
  should_run && run_step "Diff coverage ${DIFF_THRESHOLD}%: mobile (lcov)" diff_cover_mobile
fi

if [[ "${E2E}" -eq 1 ]]; then
  if [[ "${FAILURES}" -eq 0 ]]; then
    run_step "Maestro P0 suite (emulator)" maestro_p0
  else
    skip_step "Maestro P0 suite (emulator)" "skipped: earlier step failed"
  fi
fi

GATE_FINISHED=1
log ""
log "Total time: $(fmt_secs $((SECONDS - GATE_START)))"
if [[ "${FAILURES}" -eq 0 ]]; then
  log "Pre-merge check PASSED. Report: ${REPORT}"
  exit 0
fi
log "Pre-merge check FAILED (${FAILURES} step(s)). Report: ${REPORT}"
exit 1
