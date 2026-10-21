#!/usr/bin/env bash
# Fail if tracked files contain email addresses on personal / consumer mail
# domains, agent inbox domains, or non-role addresses on the product domain.
#
# Every tracked file is scanned as bytes (text, fixtures, .arb, json, yaml and
# binaries alike), including %40 / &#64; / \u0040 encodings. Findings are
# reported as path:line plus the domain only; the local part is never printed
# so CI logs do not republish the address.
#
# LANONNA_EMAIL_GUARD_ROOT overrides the repository root (tests only).
set -euo pipefail

ROOT="${LANONNA_EMAIL_GUARD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "${ROOT}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "verify-no-personal-emails.sh must run inside a git repository." >&2
  exit 1
fi

python3 - <<'PY'
import re
import subprocess
import sys

# Consumer providers, matched on the provider label with any public suffix
# (yahoo.co.uk, hotmail.fr, outlook.de, gmx.net ...).
BLOCKED_PROVIDER_LABELS = frozenset(
    {
        "gmail", "googlemail", "yahoo", "ymail", "rocketmail", "hotmail",
        "outlook", "live", "msn", "windowslive", "aol", "gmx", "yandex",
        "protonmail", "icloud", "zohomail", "tutanota",
    }
)
# Exact consumer domains whose label is too generic to match on its own.
BLOCKED_DOMAINS = frozenset(
    {
        "me.com", "mac.com", "proton.me", "pm.me", "zoho.com", "fastmail.com",
        "fastmail.fm", "hey.com", "tuta.io", "qq.com", "163.com", "126.com",
        "mail.ru", "comcast.net", "verizon.net", "att.net", "sbcglobal.net",
        # Agent inboxes used for QA belong to an operator, not the project.
        "mail.grokbot.com", "grokbot.com",
    }
)
# Product domain: only shared role addresses may appear in the public repo.
PRODUCT_DOMAINS = frozenset({"lanonna.app"})
PRODUCT_ROLE_LOCALS = frozenset(
    {"hello", "support", "noreply", "no-reply", "privacy", "legal", "security"}
)
PUBLIC_SUFFIX_2 = frozenset(
    {"co.uk", "co.jp", "co.in", "co.nz", "co.za", "com.au", "com.br", "com.mx",
     "com.ar", "com.sg", "com.tr", "co.id", "co.kr"}
)
IMAGE_TLDS = frozenset({"png", "jpg", "jpeg", "gif", "webp", "ico", "svg"})

AT = rb"(?:@|%40|&#64;|&#x40;|\\u0040|\\x40)"
EMAIL_RE = re.compile(
    rb"(?<![A-Za-z0-9._%+-])"
    rb"([A-Za-z0-9._%+-]*[A-Za-z][A-Za-z0-9._%+-]*)"
    + AT
    + rb"([A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,24})"
    rb"(?![A-Za-z0-9-]|\.[A-Za-z0-9])",
    re.IGNORECASE,
)


def provider_label(domain: str) -> str:
    parts = domain.split(".")
    if len(parts) >= 3 and ".".join(parts[-2:]) in PUBLIC_SUFFIX_2:
        return parts[-3]
    return parts[-2] if len(parts) >= 2 else domain


def reason(local: str, domain: str) -> str | None:
    domain = domain.lower()
    if domain.rsplit(".", 1)[-1] in IMAGE_TLDS:
        return None
    if domain in BLOCKED_DOMAINS or provider_label(domain) in BLOCKED_PROVIDER_LABELS:
        return f"personal mail domain {domain}"
    # Leading punctuation is shell/URL syntax (e.g. ${VAR:-hello@...}), not the address.
    local = local.lstrip("._%+-").lower()
    if domain in PRODUCT_DOMAINS and local not in PRODUCT_ROLE_LOCALS:
        return f"non-role address on {domain}"
    return None


tracked = subprocess.check_output(["git", "ls-files", "-z"]).split(b"\0")
findings: list[str] = []
for raw in tracked:
    if not raw:
        continue
    rel = raw.decode("utf-8", "surrogateescape")
    try:
        with open(raw, "rb") as fh:
            data = fh.read()
    except (FileNotFoundError, IsADirectoryError):
        continue
    for m in EMAIL_RE.finditer(data):
        local = m.group(1).decode("latin-1")
        domain = m.group(2).decode("latin-1")
        why = reason(local, domain)
        if why:
            line = data.count(b"\n", 0, m.start()) + 1
            findings.append(f"  {rel}:{line} ({why})")

if findings:
    print("Personal or non-role email addresses found in tracked files:", file=sys.stderr)
    for f in sorted(set(findings)):
        print(f, file=sys.stderr)
    print(
        "\nReplace them with placeholders (example.com / example.test) or move real values "
        "to a gitignored *.local.env file.",
        file=sys.stderr,
    )
    sys.exit(1)

print("OK: no personal or non-role email addresses in tracked files.")
PY
