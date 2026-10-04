#!/usr/bin/env bash
# Default entry: smoke suite (fast). Use run-maestro-full.sh for feature coverage.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "${ROOT}/maestro/scripts/run-maestro-smoke.sh"
