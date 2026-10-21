#!/usr/bin/env bash
# Fail if tracked files contain email addresses on blocked personal domains.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "verify-no-personal-emails.sh must run inside a git repository." >&2
  exit 1
fi

python3 - <<'PY'
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(".").resolve()
EMAIL_RE = re.compile(
    r"(?<![\w.@+-])"
    r"([A-Za-z0-9._%+-]*[A-Za-z][A-Za-z0-9._%+-]*)"
    r"@"
    r"([A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,24})"
    r"(?![\w.@-])"
)

BLOCKED_DOMAINS = frozenset(
    {
        "gmail.com",
        "googlemail.com",
        "yahoo.com",
        "hotmail.com",
        "outlook.com",
        "icloud.com",
        "live.com",
        "aol.com",
        "proton.me",
        "protonmail.com",
        "me.com",
        "msn.com",
    }
)

SKIP_SUFFIXES = frozenset(
    {
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".webp",
        ".ico",
        ".pdf",
        ".woff",
        ".woff2",
        ".ttf",
        ".eot",
        ".zip",
        ".jar",
        ".apk",
        ".aab",
    }
)

IMAGE_TLDS = frozenset({"png", "jpg", "jpeg", "gif", "webp", "ico", "svg"})


def looks_like_email(local: str, domain: str) -> bool:
    domain_l = domain.lower()
    tld = domain_l.rsplit(".", 1)[-1]
    if tld in IMAGE_TLDS:
        return False
    if ".." in domain_l or domain_l.startswith(".") or domain_l.endswith("."):
        return False
    return True


tracked = subprocess.check_output(["git", "ls-files"], text=True).splitlines()
violations: list[tuple[str, int, str, str]] = []

for rel in tracked:
    path = ROOT / rel
    if not path.is_file():
        continue
    if path.suffix.lower() in SKIP_SUFFIXES:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    for local, domain in EMAIL_RE.findall(text):
        if not looks_like_email(local, domain):
            continue
        if domain.lower() in BLOCKED_DOMAINS:
            violations.append((rel, 0, domain, ""))

if violations:
    print("Blocked personal email domains found in tracked files:", file=sys.stderr)
    seen: set[tuple[str, str]] = set()
    for rel, _lineno, domain, _snippet in violations:
        key = (rel, domain.lower())
        if key in seen:
            continue
        seen.add(key)
        # re-scan for line numbers (cheap for small violation sets)
        text = (ROOT / rel).read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), start=1):
            if f"@{domain}" in line and domain.lower() in BLOCKED_DOMAINS:
                print(f"  {rel}:{lineno} (@{domain}) {line.strip()[:120]}", file=sys.stderr)
                break
    print(
        "\nBlocked domains include: " + ", ".join(sorted(BLOCKED_DOMAINS)),
        file=sys.stderr,
    )
    sys.exit(1)

print("OK: no blocked personal email domains in tracked files.")
PY
