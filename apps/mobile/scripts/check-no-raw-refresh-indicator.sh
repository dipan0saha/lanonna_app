#!/usr/bin/env bash
# Fail if lib/ builds a Material RefreshIndicator outside the shared wrapper.
# Pull-to-refresh goes through core/widgets/app_refresh_indicator.dart
# (AppRefreshIndicator), which reports refresh failures so a reload never
# ends silently (#421).
#
# POSIX grep -E, same as check-no-material-chips.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

WRAPPER='lib/core/widgets/app_refresh_indicator.dart'
PATTERN='(^|[^A-Za-z0-9_])RefreshIndicator(\.adaptive)?[[:space:]]*[<(]'

# grep exits 0 on a match, 1 on no match, >1 on error.
status=0
all="$(grep -rnE --include='*.dart' "${PATTERN}" lib/)" || status=$?
if [[ ${status} -gt 1 ]]; then
  echo "FAIL: grep error (exit ${status}) while scanning lib/" >&2
  exit 2
fi
matches="$(printf '%s\n' "${all}" | grep -v -e "^${WRAPPER}:" -e '^$' || true)"

if [[ -n "${matches}" ]]; then
  echo "${matches}"
  echo ""
  echo "FAIL: raw RefreshIndicator found. Use AppRefreshIndicator from core/widgets/app_refresh_indicator.dart."
  exit 1
fi

echo "OK: pull-to-refresh uses AppRefreshIndicator only"
