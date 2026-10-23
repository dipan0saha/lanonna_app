#!/usr/bin/env bash
# Fail if lib/ uses Material chips (Chip, FilterChip, ...) or Material segmented
# controls (SegmentedButton, ToggleButtons). Use core/widgets/app_chip.dart:
# AppToggleChip / AppRemovableChip / AppBadgeChip, and AppToggleChipBar for
# exactly-one view switchers.
#
# Uses POSIX grep -E (no ripgrep dependency) so the check runs the same on CI
# and on developer machines, and fails loudly instead of passing when the
# search tool itself errors.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

# A constructor call or generic instantiation, not part of a longer identifier
# (AppToggleChip, AppToggleChipBar) and not a mention in prose.
WORD_START='(^|[^A-Za-z0-9_])'
CHIP_PATTERN="${WORD_START}(Chip|FilterChip|InputChip|ChoiceChip|ActionChip|RawChip)[[:space:]]*[<(]"
SEGMENT_PATTERN="${WORD_START}(SegmentedButton|ToggleButtons)[[:space:]]*[<(]"

# grep exits 0 on a match, 1 on no match, >1 on error.
find_matches() {
  local pattern="$1"
  local status=0
  grep -rnE --include='*.dart' "${pattern}" lib/ || status=$?
  if [[ ${status} -gt 1 ]]; then
    echo "FAIL: grep error (exit ${status}) while scanning lib/" >&2
    exit 2
  fi
  return "${status}"
}

failed=0

if find_matches "${CHIP_PATTERN}"; then
  echo ""
  echo "FAIL: Material chip widgets found. Use AppToggleChip, AppRemovableChip, or AppBadgeChip."
  failed=1
fi

if find_matches "${SEGMENT_PATTERN}"; then
  echo ""
  echo "FAIL: Material segmented controls found. Use AppToggleChipBar from app_chip.dart."
  failed=1
fi

if [[ ${failed} -ne 0 ]]; then
  exit 1
fi

echo "OK: no Material Chip or segmented controls in lib/"
