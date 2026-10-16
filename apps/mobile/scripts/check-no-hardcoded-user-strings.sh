#!/usr/bin/env bash
# Blocks new hardcoded user-facing Text('…') literals under lib/ (use ARB + gen-l10n).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWLIST="${ROOT}/tool/hardcoded_user_strings_allowlist.txt"

cd "${ROOT}"

mapfile -t ALLOWED < <(grep -v '^\s*#' "${ALLOWLIST}" | grep -v '^\s*$' || true)

violations=()
while IFS= read -r entry; do
  violations+=("${entry}")
done < <(
  python3 - "${ROOT}/lib" << 'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
pat = re.compile(r"\bText\s*\(\s*('([^'\\]|\\.)*'|\"([^\"\\]|\\.)*\")")
for path in sorted(root.rglob("*.dart")):
    if "l10n/" in str(path):
        continue
    for i, line in enumerate(path.read_text().splitlines(), 1):
        if "Text(" not in line:
            continue
        if "l10n." in line or "AppLocalizations" in line:
            continue
        if not pat.search(line):
            continue
        print(f"{path.relative_to(root.parent)}:{i}")
PY
)

declare -A allowed_map=()
for row in "${ALLOWED[@]}"; do
  key="${row%%:*}"
  rest="${row#*:}"
  key="${key}:${rest%%:*}"
  allowed_map["${key}"]=1
done

new=()
for v in "${violations[@]}"; do
  if [[ -z "${allowed_map[$v]:-}" ]]; then
    new+=("${v}")
  fi
done

if ((${#new[@]} > 0)); then
  echo "Hardcoded Text() literals found outside l10n (add to ARB or allowlist with justification):"
  printf '  %s\n' "${new[@]}"
  exit 1
fi

echo "OK: no new hardcoded user-facing Text literals."
