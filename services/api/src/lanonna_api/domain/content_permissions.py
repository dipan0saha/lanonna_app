"""Viewer capabilities on baby-scoped member content (comments, name suggestions, etc.)."""

from __future__ import annotations

from typing import Any


def is_baby_owner(membership: dict[str, Any] | None) -> bool:
    return membership is not None and membership.get("role") == "owner"


def member_content_can_edit(viewer_uid: str, author_uid: str) -> bool:
    return author_uid == viewer_uid


def member_content_can_delete(
    viewer_uid: str,
    membership: dict[str, Any] | None,
    author_uid: str,
) -> bool:
    return is_baby_owner(membership) or author_uid == viewer_uid


def member_comment_capabilities(
    viewer_uid: str,
    membership: dict[str, Any] | None,
    author_uid: str,
) -> dict[str, bool]:
    is_mine = author_uid == viewer_uid
    return {
        "is_mine": is_mine,
        "can_edit": member_content_can_edit(viewer_uid, author_uid),
        "can_delete": member_content_can_delete(viewer_uid, membership, author_uid),
    }


def member_comment_to_json(
    row: dict[str, Any],
    viewer_uid: str,
    membership: dict[str, Any] | None,
    author_display_name: str,
) -> dict[str, Any]:
    author_uid = row["author_firebase_uid"]
    caps = member_comment_capabilities(viewer_uid, membership, author_uid)
    return {
        "id": str(row["id"]),
        "body": row["body"],
        "author_display_name": author_display_name,
        "author_firebase_uid": author_uid,
        "created_at": row["created_at"].isoformat(),
        **caps,
    }
