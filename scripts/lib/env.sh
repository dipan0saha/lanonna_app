# Shared GCP project / environment resolution for deploy and ops scripts.
# Source this file from a bash script; do not execute it.
# shellcheck shell=bash
#
# Rules (fail closed, never fall back to dev for a prod request):
# - GCP_PROJECT_ID unset and ENVIRONMENT unset or dev -> lanonna-dev / dev.
# - GCP_PROJECT_ID unset and ENVIRONMENT=prod -> error (prod must name its project).
# - GCP_PROJECT_ID must be lanonna-dev or lanonna-prod; anything else is an error.
# - A pre-set ENVIRONMENT that disagrees with GCP_PROJECT_ID is an error.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "scripts/lib/env.sh must be sourced from bash." >&2
  return 1
fi
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "scripts/lib/env.sh is a library; source it instead of executing it." >&2
  exit 1
fi
set -euo pipefail

# Repo root (directory that contains infra/env/). Override with LANONNA_REPO_ROOT.
lanonna_repo_root() {
  if [[ -n "${LANONNA_REPO_ROOT:-}" ]]; then
    printf '%s\n' "${LANONNA_REPO_ROOT}"
    return 0
  fi
  (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
}

# Resolve and export GCP_PROJECT_ID and ENVIRONMENT (dev|prod) together.
lanonna_resolve_environment() {
  local requested="${ENVIRONMENT:-}"
  case "${requested}" in
    "" | dev | prod) ;;
    *)
      echo "Invalid ENVIRONMENT=${requested} (expected dev or prod)." >&2
      return 1
      ;;
  esac

  if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
    if [[ "${requested}" == "prod" ]]; then
      echo "ENVIRONMENT=prod requires GCP_PROJECT_ID=lanonna-prod; refusing to default to lanonna-dev." >&2
      return 1
    fi
    GCP_PROJECT_ID="lanonna-dev"
  fi

  local derived
  case "${GCP_PROJECT_ID}" in
    lanonna-dev) derived=dev ;;
    lanonna-prod) derived=prod ;;
    *)
      echo "Unknown GCP_PROJECT_ID=${GCP_PROJECT_ID} (expected lanonna-dev or lanonna-prod)." >&2
      return 1
      ;;
  esac

  if [[ -n "${requested}" && "${requested}" != "${derived}" ]]; then
    echo "ENVIRONMENT=${requested} does not match GCP_PROJECT_ID=${GCP_PROJECT_ID} (${derived})." >&2
    return 1
  fi

  ENVIRONMENT="${derived}"
  export GCP_PROJECT_ID ENVIRONMENT
}

# Kept for callers that only need the project id; validates the same way.
lanonna_resolve_gcp_project_id() {
  lanonna_resolve_environment
}

# Path of infra/env/<environment>.<component>.env. Call lanonna_resolve_environment first.
lanonna_infra_env_file() {
  local component="$1"
  case "${component}" in
    api | worker) ;;
    *)
      echo "lanonna_infra_env_file: invalid component ${component}" >&2
      return 1
      ;;
  esac
  if [[ -z "${ENVIRONMENT:-}" ]]; then
    lanonna_resolve_environment
  fi
  printf '%s/infra/env/%s.%s.env\n' "$(lanonna_repo_root)" "${ENVIRONMENT}" "${component}"
}

# True when a value is an explicit repo placeholder such as __SET_PROD_X__.
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
