from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.config import settings
from lanonna_api.domain import assert_owner_membership, create_pending_photo
from lanonna_api.repositories.babies import get_baby_membership
from lanonna_api.repositories.photos import (
    caller_squished,
    delete_photo,
    get_photo_for_baby,
    insert_photo_comment,
    list_photo_comments,
    list_photos_for_baby,
    soft_delete_photo_comment,
    squish_count,
    toggle_squish,
    update_photo_caption,
    update_photo_comment,
)
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.storage import mint_display_upload_for_object, mint_signed_read_url


def _display_name(row: dict[str, Any]) -> str:
    if row.get("uploader_display_name"):
        return row["uploader_display_name"]
    email = row.get("uploader_email") or row.get("author_email") or ""
    if email and "@" in email:
        return email.split("@")[0]
    return "Family member"


def _thumb_url(thumb_path: str | None) -> str | None:
    if not thumb_path:
        return None
    return mint_signed_read_url(settings.thumbnails_bucket, thumb_path)


def _display_url(display_path: str | None) -> str | None:
    if not display_path:
        return None
    return mint_signed_read_url(settings.display_bucket, display_path)


def require_membership(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict[str, Any]:
    membership = get_baby_membership(firebase_uid, baby_profile_id)
    if membership is None:
        raise PermissionError("Baby membership required.")
    return membership


def init_photo_upload(
    user: dict[str, Any],
    baby_profile_id: uuid.UUID,
    content_type: str,
    byte_length: int,
    max_bytes: int = 2_097_152,
) -> dict[str, Any]:
    if byte_length > max_bytes:
        raise ValueError("Display asset exceeds maximum size.")
    upsert_app_user(user["uid"], user.get("email"))
    assert_owner_membership(user["uid"], baby_profile_id)
    photo = create_pending_photo(
        baby_profile_id,
        user["uid"],
        content_type,
        byte_length,
    )
    signed = mint_display_upload_for_object(
        photo["display_path"],
        content_type=content_type,
        max_bytes=max_bytes,
    )
    return {
        "photo_id": str(photo["id"]),
        **signed,
    }


def list_gallery(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    limit: int = 50,
    offset: int = 0,
) -> list[dict[str, Any]]:
    membership = require_membership(firebase_uid, baby_profile_id)
    ready_only = membership["role"] != "owner"
    rows = list_photos_for_baby(
        baby_profile_id,
        ready_only=ready_only,
        limit=limit,
        offset=offset,
    )
    out = []
    for row in rows:
        out.append(
            {
                "id": str(row["id"]),
                "status": row["status"],
                "caption": row.get("caption"),
                "created_at": row["created_at"].isoformat(),
                "thumb_url": _thumb_url(row.get("thumb_path")),
                "squish_count": row["squish_count"],
                "comment_count": row["comment_count"],
                "uploader_display_name": _display_name(row),
            }
        )
    return out


def get_photo_detail(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
) -> dict[str, Any]:
    membership = require_membership(firebase_uid, baby_profile_id)
    row = get_photo_for_baby(baby_profile_id, photo_id)
    if row is None:
        raise LookupError("Photo not found.")
    if membership["role"] != "owner" and row["status"] != "ready":
        raise PermissionError("Photo not available.")
    comments = list_photo_comments(photo_id)
    squished = caller_squished(photo_id, firebase_uid)
    return {
        "id": str(row["id"]),
        "status": row["status"],
        "caption": row.get("caption"),
        "created_at": row["created_at"].isoformat(),
        "display_url": _display_url(row.get("display_path")),
        "thumb_url": _thumb_url(row.get("thumb_path")),
        "uploader_display_name": _display_name(row),
        "squish_count": squish_count(photo_id),
        "viewer_has_squished": squished,
        "comments": [
            {
                "id": str(c["id"]),
                "body": c["body"],
                "author_display_name": _display_name(c),
                "author_firebase_uid": c["author_firebase_uid"],
                "created_at": c["created_at"].isoformat(),
                "is_mine": c["author_firebase_uid"] == firebase_uid,
            }
            for c in comments
        ],
    }


def patch_caption(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    caption: str | None,
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    row = update_photo_caption(baby_profile_id, photo_id, caption)
    if row is None:
        raise LookupError("Photo not found.")
    return {"id": str(photo_id), "caption": row.get("caption")}


def remove_photo(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
) -> None:
    assert_owner_membership(firebase_uid, baby_profile_id)
    if not delete_photo(baby_profile_id, photo_id):
        raise LookupError("Photo not found.")


def squish_photo(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    row = get_photo_for_baby(baby_profile_id, photo_id)
    if row is None or row["status"] != "ready":
        raise LookupError("Photo not found.")
    active = toggle_squish(photo_id, firebase_uid)
    return {"squished": active}


def add_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    body: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    row = get_photo_for_baby(baby_profile_id, photo_id)
    if row is None or row["status"] != "ready":
        raise LookupError("Photo not found.")
    if not body.strip():
        raise ValueError("Comment body required.")
    upsert_app_user(firebase_uid, None)
    c = insert_photo_comment(photo_id, firebase_uid, body)
    return {
        "id": str(c["id"]),
        "body": c["body"],
        "created_at": c["created_at"].isoformat(),
    }


def edit_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
    body: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    if not body.strip():
        raise ValueError("Comment body required.")
    row = update_photo_comment(photo_id, comment_id, firebase_uid, body)
    if row is None:
        raise LookupError("Comment not found.")
    return {"id": str(row["id"]), "body": row["body"]}


def delete_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
) -> None:
    require_membership(firebase_uid, baby_profile_id)
    if not soft_delete_photo_comment(photo_id, comment_id, firebase_uid):
        raise LookupError("Comment not found.")
