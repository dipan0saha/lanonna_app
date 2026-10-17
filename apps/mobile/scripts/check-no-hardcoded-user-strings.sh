#!/usr/bin/env bash
# Blocks hardcoded user-facing string literals under lib/ (use ARB + gen-l10n).
#
# Genuine exceptions: apps/mobile/tool/hardcoded_user_strings_allowlist.txt
# Format: path|exact literal|justification
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
dart run tool/check_hardcoded_user_strings.dart "$ROOT"
