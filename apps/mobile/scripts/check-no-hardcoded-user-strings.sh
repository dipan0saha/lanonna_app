#!/usr/bin/env bash
# Blocks hardcoded user-facing Text('…') literals under lib/ (use the ARB + gen-l10n).
#
# A literal is user-facing when it contains letters outside `$…` interpolations.
# Symbol/number-only literals ('🎁', '$count', '• $item') carry no translatable
# copy and are not flagged. Genuine exceptions go in the allowlist as
# `path|exact literal|justification`, matched by content, not line number.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "${ROOT}" << 'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
allow = set()
for raw in (root / "tool/hardcoded_user_strings_allowlist.txt").read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split("|")
    if len(parts) != 3 or not parts[2].strip():
        sys.exit(f"Allowlist entry needs path|literal|justification: {raw}")
    allow.add((parts[0].strip(), parts[1]))

pat = re.compile(r"\bText\s*\(\s*('(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\")")
interp = re.compile(r"\$\{[^}]*\}|\$\w+")
violations = []
for path in sorted((root / "lib").rglob("*.dart")):
    rel = str(path.relative_to(root))
    if rel.startswith("lib/l10n/"):
        continue
    for i, line in enumerate(path.read_text().splitlines(), 1):
        for m in pat.finditer(line):
            literal = m.group(1)[1:-1]
            if not re.search(r"[A-Za-z]", interp.sub("", literal)):
                continue
            if (rel, literal) in allow:
                continue
            violations.append(f"{rel}:{i}: {m.group(1)}")

if violations:
    print("Hardcoded user-facing Text() literals (move to lib/l10n/app_en.arb):")
    print("\n".join(f"  {v}" for v in violations))
    sys.exit(1)
print("OK: no hardcoded user-facing Text literals.")
PY
