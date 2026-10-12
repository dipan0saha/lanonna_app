"""Render Android App Links and iOS universal-link files for invite hosting."""

from __future__ import annotations

import json
import re
from typing import Any

ANDROID_PACKAGE = "com.lanonna.lanonna"
IOS_BUNDLE_ID = "com.lanonna.lanonna"

_SHA256 = re.compile(r"^[0-9A-F]{2}(?::[0-9A-F]{2}){31}$")

INVITE_UNIVERSAL_PATHS = [
    "/invite",
    "/invite/*",
    "/__/auth/action",
    "/__/auth/action/*",
]


def normalize_sha256_fingerprints(raw: list[str]) -> list[str]:
    fingerprints: list[str] = []
    seen: set[str] = set()
    for item in raw:
        compact = re.sub(r"[^0-9A-Fa-f]", "", item).upper()
        if len(compact) != 64:
            raise ValueError("Android SHA-256 fingerprint must be 64 hex characters.")
        formatted = ":".join(compact[i : i + 2] for i in range(0, 64, 2))
        if formatted not in seen:
            seen.add(formatted)
            fingerprints.append(formatted)
        if not _SHA256.match(formatted):
            raise ValueError("Android SHA-256 fingerprint is not valid.")
    if not fingerprints:
        raise ValueError("At least one Android SHA-256 fingerprint is required.")
    return fingerprints


def render_assetlinks(
    fingerprints: list[str],
    *,
    package_name: str = ANDROID_PACKAGE,
) -> list[dict[str, Any]]:
    return [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": package_name,
                "sha256_cert_fingerprints": normalize_sha256_fingerprints(fingerprints),
            },
        }
    ]


def render_apple_app_site_association(
    team_id: str | None,
    *,
    bundle_id: str = IOS_BUNDLE_ID,
) -> dict[str, Any]:
    """Universal links for /invite. Auth action paths stay claimed too.

    Without an Apple Team ID the details list is empty, so iOS opens the
    web fallback instead of the app. Android App Links do not use this file.
    """
    details: list[dict[str, Any]] = []
    cleaned = (team_id or "").strip()
    if cleaned:
        if not re.fullmatch(r"[A-Z0-9]{10}", cleaned):
            raise ValueError("APPLE_TEAM_ID must be 10 letters or digits.")
        details.append(
            {
                "appID": f"{cleaned}.{bundle_id}",
                "paths": list(INVITE_UNIVERSAL_PATHS),
            }
        )
    return {"applinks": {"apps": [], "details": details}}


def dumps(value: Any) -> str:
    return json.dumps(value, indent=2) + "\n"
