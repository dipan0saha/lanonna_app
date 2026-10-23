#!/usr/bin/env bash
# Prints the Firebase Web API key from flavor-specific mobile options.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ENV="${APP_ENV:-dev}"
OPTIONS_FILE="${ROOT}/apps/mobile/lib/firebase/firebase_options_${APP_ENV}.dart"

if [[ ! -f "${OPTIONS_FILE}" ]]; then
  echo "Firebase options not found: ${OPTIONS_FILE} (APP_ENV=${APP_ENV})" >&2
  exit 1
fi

python3 - "${OPTIONS_FILE}" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
match = re.search(r"apiKey:\s*'([^']+)'", text)
if not match:
    sys.exit(f"No apiKey found in {path}")
print(match.group(1))
PY
