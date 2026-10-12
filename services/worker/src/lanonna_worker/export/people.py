"""Person labels for the baby export.

Matches the API display-name rule in ``domain/users_display.py``: use
``app_users.display_name`` only, never an email. Empty name → "Family member".
An activity actor with no profile row → "Someone".
"""

from __future__ import annotations

import hashlib
import json
import uuid
from typing import Any

FAMILY_MEMBER_LABEL = "Family member"
UNKNOWN_ACTOR_LABEL = "Someone"
ANONYMOUS_LABEL = "Anonymous"

_SENSITIVE_KEYS = frozenset(
    {
        "firebase_uid",
        "email",
        "invitee_email",
        "token",
        "token_hash",
        "email_invite_token",
        "invite_token",
    }
)


class ExportPrivacyError(RuntimeError):
    """The document would have leaked a UID, member email, or invite secret."""


def person_id_for(baby_id: uuid.UUID, firebase_uid: str) -> str:
    """Stable id for this baby. Not reversible to the Firebase UID."""
    digest = hashlib.sha256(f"{baby_id}:{firebase_uid}".encode("utf-8")).hexdigest()
    return f"person_{digest[:16]}"


def export_display_name(raw: Any, *, unknown_actor: bool = False) -> str:
    text = str(raw).strip() if raw is not None else ""
    if text:
        return text
    return UNKNOWN_ACTOR_LABEL if unknown_actor else FAMILY_MEMBER_LABEL


def scrub_payload(value: Any, uid_to_person: dict[str, str]) -> Any:
    """Drop secret keys and rewrite Firebase UIDs to person ids."""
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for key, item in value.items():
            if key in _SENSITIVE_KEYS or key.endswith("_firebase_uid") or key.endswith("_email"):
                if isinstance(item, str) and item in uid_to_person:
                    cleaned["person_id"] = uid_to_person[item]
                continue
            cleaned[key] = scrub_payload(item, uid_to_person)
        return cleaned
    if isinstance(value, list):
        return [scrub_payload(item, uid_to_person) for item in value]
    if isinstance(value, str) and value in uid_to_person:
        return uid_to_person[value]
    return value


def assert_export_privacy(
    document: dict[str, Any],
    *,
    firebase_uids: set[str],
    member_emails: set[str],
    secrets: set[str],
) -> None:
    """Fail closed if a raw UID, member email, or invite secret is in the JSON.

    A member email that is also that member's published display name is allowed:
    the app already shows that label. The error text never includes the value.
    """
    published: set[str] = set()

    def _walk(value: Any) -> None:
        if isinstance(value, dict):
            name = value.get("display_name")
            if isinstance(name, str) and name.strip():
                published.add(name.strip().lower())
            for item in value.values():
                _walk(item)
        elif isinstance(value, list):
            for item in value:
                _walk(item)

    _walk(document)
    blob = json.dumps(document, ensure_ascii=False)
    blob_lower = blob.lower()
    for uid in firebase_uids:
        if uid and uid in blob:
            raise ExportPrivacyError("Export document failed the privacy check.")
    for email in member_emails:
        normalized = email.strip().lower()
        if not normalized or normalized in published:
            continue
        if normalized in blob_lower:
            raise ExportPrivacyError("Export document failed the privacy check.")
    for secret in secrets:
        if secret and secret in blob:
            raise ExportPrivacyError("Export document failed the privacy check.")
