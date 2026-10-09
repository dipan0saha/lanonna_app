from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain import assert_owner_membership, create_pending_photo
from lanonna_api.domain.media_urls import signed_display_url, signed_thumb_url
from lanonna_api.repositories.babies import get_baby_membership, list_babies_for_user
from lanonna_api.repositories.photo_tags import (
    list_tagged_babies_for_photo,
    replace_photo_baby_tags,
)
from lanonna_api.domain.content_permissions import (
    member_comment_to_json,
    member_content_can_delete,
    member_content_can_edit,
)
from lanonna_api.repositories.photos import (
    PhotoListSort,
    caller_squished,
    delete_photo,
    get_photo_comment,
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
from lanonna_api.domain.activity_copy import (
    EVENT_PHOTO_COMMENT,
    EVENT_PHOTO_SQUISH,
    photo_comment_summary,
    photo_squish_summary,
)
from lanonna_api.domain.notification_copy import actor_display_name
from lanonna_api.domain.users_display import (
    author_display_name_from_row,
    uploader_display_name_from_row,
)
from lanonna_api.domain.notifications import NotificationChannel, safe_enqueue_notify_user
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.repositories.users import upsert_app_user
from lanonna_api.storage import mint_display_upload_for_object, mint_signed_read_url


def _tagged_babies_json(
    photo_id: uuid.UUID,
    viewer_firebase_uid: str,
) -> list[dict[str, str]]:
    tagged = list_tagged_babies_for_photo(photo_id, viewer_firebase_uid)
    return [{"id": str(t["id"]), "name": t["name"]} for t in tagged]


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
    caption: str | None = None,
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
        caption,
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
    sort: str = "default",
) -> list[dict[str, Any]]:
    membership = require_membership(firebase_uid, baby_profile_id)
    ready_only = membership["role"] != "owner"
    sort_param: PhotoListSort = (
        sort if sort in ("default", "recent", "favorites") else "default"
    )
    rows = list_photos_for_baby(
        baby_profile_id,
        ready_only=ready_only,
        limit=limit,
        offset=offset,
        sort=sort_param,
    )
    out = []
    for row in rows:
        out.append(
            {
                "id": str(row["id"]),
                "status": row["status"],
                "caption": row.get("caption"),
                "created_at": row["created_at"].isoformat(),
                "thumb_url": signed_thumb_url(row.get("thumb_path")),
                "squish_count": row["squish_count"],
                "comment_count": row["comment_count"],
                "uploader_display_name": uploader_display_name_from_row(row),
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
        "display_url": signed_display_url(row.get("display_path")),
        "thumb_url": signed_thumb_url(row.get("thumb_path")),
        "uploader_display_name": uploader_display_name_from_row(row),
        "squish_count": squish_count(photo_id),
        "viewer_has_squished": squished,
        "tagged_babies": _tagged_babies_json(photo_id, firebase_uid),
        "comments": [
            member_comment_to_json(
                c, firebase_uid, membership, author_display_name_from_row(c)
            )
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
    if active:
        actor = actor_display_name(firebase_uid)
        insert_activity_event(
            baby_profile_id,
            firebase_uid,
            EVENT_PHOTO_SQUISH,
            photo_squish_summary(actor, row.get("caption")),
            {"photo_id": str(photo_id)},
        )
    uploader = row["uploader_firebase_uid"]
    if active and uploader != firebase_uid:
        actor = actor_display_name(firebase_uid)
        safe_enqueue_notify_user(
            uploader,
            title="New squish",
            body=f"{actor} squished your photo",
            deep_link=f"/gallery/photo/{photo_id}",
            baby_profile_id=baby_profile_id,
            notification_channel=NotificationChannel.GALLERY,
        )
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
    actor = actor_display_name(firebase_uid)
    insert_activity_event(
        baby_profile_id,
        firebase_uid,
        EVENT_PHOTO_COMMENT,
        photo_comment_summary(actor, row.get("caption")),
        {"photo_id": str(photo_id), "comment_id": str(c["id"])},
    )
    uploader = row["uploader_firebase_uid"]
    if uploader != firebase_uid:
        actor = actor_display_name(firebase_uid)
        safe_enqueue_notify_user(
            uploader,
            title="New comment",
            body=f"{actor} commented on your photo",
            deep_link=f"/gallery/photo/{photo_id}",
            baby_profile_id=baby_profile_id,
            notification_channel=NotificationChannel.COMMENTS,
        )
    return {
        "id": str(c["id"]),
        "body": c["body"],
        "created_at": c["created_at"].isoformat(),
    }


def delete_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
) -> None:
    membership = require_membership(firebase_uid, baby_profile_id)
    row = get_photo_for_baby(baby_profile_id, photo_id)
    if row is None:
        raise LookupError("Photo not found.")
    comment = get_photo_comment(photo_id, comment_id)
    if comment is None:
        raise LookupError("Comment not found.")
    if not member_content_can_delete(
        firebase_uid, membership, comment["author_firebase_uid"]
    ):
        raise PermissionError("Cannot delete this comment.")
    if not soft_delete_photo_comment(photo_id, comment_id):
        raise LookupError("Comment not found.")


def edit_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
    body: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    row = get_photo_for_baby(baby_profile_id, photo_id)
    if row is None or row["status"] != "ready":
        raise LookupError("Photo not found.")
    if not body.strip():
        raise ValueError("Comment body required.")
    comment = get_photo_comment(photo_id, comment_id)
    if comment is None:
        raise LookupError("Comment not found.")
    if not member_content_can_edit(firebase_uid, comment["author_firebase_uid"]):
        raise PermissionError("Cannot edit this comment.")
    updated = update_photo_comment(
        photo_id,
        comment_id,
        comment["author_firebase_uid"],
        body,
    )
    if updated is None:
        raise LookupError("Comment not found.")
    return {
        "id": str(updated["id"]),
        "body": updated["body"],
        "updated_at": updated["updated_at"].isoformat(),
    }


def set_photo_baby_tags(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID,
    tagged_baby_profile_ids: list[uuid.UUID],
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    row = get_photo_for_baby(baby_profile_id, photo_id)
    if row is None:
        raise LookupError("Photo not found.")
    user_baby_ids = {
        uuid.UUID(str(b["id"])) for b in list_babies_for_user(firebase_uid)
    }
    unique_ids: list[uuid.UUID] = []
    seen: set[uuid.UUID] = set()
    for baby_id in tagged_baby_profile_ids:
        if baby_id not in user_baby_ids:
            raise PermissionError("Cannot tag that baby.")
        if baby_id in seen:
            continue
        seen.add(baby_id)
        unique_ids.append(baby_id)
    replace_photo_baby_tags(photo_id, unique_ids)
    return {
        "tagged_babies": _tagged_babies_json(photo_id, firebase_uid),
    }
