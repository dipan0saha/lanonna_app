#!/usr/bin/env bash
# Keep worker Docker templates in sync with packages/email-templates (source of truth).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/packages/email-templates"
DST="${ROOT}/services/worker/email_templates"

if [[ ! -d "$SRC" ]]; then
  echo "Missing $SRC" >&2
  exit 1
fi

MODE="${1:-check}"

sync_file() {
  local name="$1"
  if [[ ! -f "${SRC}/${name}" ]]; then
    echo "Missing source ${SRC}/${name}" >&2
    exit 1
  fi
  if [[ "$MODE" == "apply" ]]; then
    cp "${SRC}/${name}" "${DST}/${name}"
    echo "Copied ${name}"
  elif ! cmp -s "${SRC}/${name}" "${DST}/${name}"; then
    echo "Drift: ${name} (run: $0 apply)" >&2
    return 1
  fi
}

fail=0
for f in invite_v1.html invite_v1.txt; do
  sync_file "$f" || fail=1
done

if [[ "$MODE" == "check" && "$fail" -eq 0 ]]; then
  echo "Email templates in sync."
fi
exit "$fail"
