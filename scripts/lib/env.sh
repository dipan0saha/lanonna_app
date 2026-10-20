# Shared GCP project / environment resolution for deploy and ops scripts.
# Source this file; do not execute it.
# shellcheck shell=bash

# Repo root (directory that contains infra/env/). Override with LANONNA_REPO_ROOT.
lanonna_repo_root() {
  if [[ -n "${LANONNA_REPO_ROOT:-}" ]]; then
    printf '%s\n' "${LANONNA_REPO_ROOT}"
    return 0
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "${here}"
}

# Default lanonna-dev preserves existing Mac dev deploy behavior.
lanonna_resolve_gcp_project_id() {
  GCP_PROJECT_ID="${GCP_PROJECT_ID:-lanonna-dev}"
  export GCP_PROJECT_ID
}

# Resolve ENVIRONMENT (dev|prod). Honors a pre-set ENVIRONMENT; otherwise maps known project ids.
lanonna_resolve_environment() {
  if [[ -n "${ENVIRONMENT:-}" ]]; then
    case "${ENVIRONMENT}" in
      dev | prod) export ENVIRONMENT; return 0 ;;
      *)
        echo "Invalid ENVIRONMENT=${ENVIRONMENT} (expected dev or prod)." >&2
        return 1
        ;;
    esac
  fi
  lanonna_resolve_gcp_project_id
  case "${GCP_PROJECT_ID}" in
    lanonna-dev) ENVIRONMENT=dev ;;
    lanonna-prod) ENVIRONMENT=prod ;;
    *)
      cat >&2 <<EOF
Unknown GCP_PROJECT_ID=${GCP_PROJECT_ID}.
Set ENVIRONMENT=dev or ENVIRONMENT=prod explicitly, or use lanonna-dev / lanonna-prod.
EOF
      return 1
      ;;
  esac
  export ENVIRONMENT
}

lanonna_infra_env_file() {
  local component="$1"
  case "${component}" in
    api | worker) ;;
    *)
      echo "lanonna_infra_env_file: invalid component ${component}" >&2
      return 1
      ;;
  esac
  lanonna_resolve_environment
  printf '%s/infra/env/%s.%s.env\n' "$(lanonna_repo_root)" "${ENVIRONMENT}" "${component}"
}

# True when a value is an explicit repo placeholder (fail fast).
lanonna_is_placeholder_value() {
  local value="$1"
  [[ "${value}" =~ ^__[A-Z0-9_]+__$ ]]
}

lanonna_reject_placeholder() {
  local name="$1"
  local value="$2"
  if lanonna_is_placeholder_value "${value}"; then
    echo "${name} is still the placeholder ${value}. Set a real value before deploying this environment." >&2
    return 1
  fi
  return 0
}
