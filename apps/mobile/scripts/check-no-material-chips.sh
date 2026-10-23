#!/usr/bin/env bash
# Fail if lib/ uses Material Chip / FilterChip / etc. (use core/widgets/app_chip.dart).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

PATTERN='\\b(FilterChip|InputChip|ChoiceChip|ActionChip)\\s*\\(|\\bChip\\s*\\('
if rg -n "${PATTERN}" lib/ --glob '!**/app_chip.dart' 2>/dev/null; then
  echo ""
  echo "FAIL: Material chip widgets found. Use AppToggleChip, AppRemovableChip, or AppBadgeChip."
  exit 1
fi

SEGMENT_PATTERN='\\b(SegmentedButton|ToggleButtons)\\s*[<(]'
if rg -n "${SEGMENT_PATTERN}" lib/ 2>/dev/null; then
  echo ""
  echo "FAIL: Material segmented controls found. Use AppToggleChipBar from app_chip.dart."
  exit 1
fi

echo "OK: no Material Chip or segmented controls in lib/"
