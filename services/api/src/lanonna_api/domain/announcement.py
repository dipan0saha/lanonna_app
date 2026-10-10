from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from lanonna_api.config import settings
from lanonna_api.domain.announcement_validation import (
    merge_announcement_patch,
    validate_announcement_fields,
)
from lanonna_api.domain.gallery import require_membership
from lanonna_api.domain.membership import assert_owner_membership
from lanonna_api.repositories.photos import get_photo_for_baby
from lanonna_api.repositories.announcements import (
    add_comment,
    get_announcement,
    list_comments,
    toggle_squish,
    upsert_announcement,
)
from lanonna_api.storage import mint_signed_read_url


def _require_baby_announcement_photo(
    baby_profile_id: uuid.UUID,
    photo_id: uuid.UUID | None,
) -> None:
    if photo_id is None:
        return
    if get_photo_for_baby(baby_profile_id, photo_id) is None:
        raise ValueError("Photo must belong to this baby profile.")


def _photo_display_url(baby_profile_id: uuid.UUID, photo_id: uuid.UUID | None) -> str | None:
    if photo_id is None:
        return None
    row = get_photo_for_baby(baby_profile_id, photo_id)
    if row is None:
        return None
    path = row.get("display_path")
    if not path:
        return None
    return mint_signed_read_url(settings.display_bucket, path)


def _serialize(ann: dict[str, Any], comments: list[dict[str, Any]]) -> dict[str, Any]:
    bd = ann.get("birth_date")
    baby_id = ann["baby_profile_id"]
    photo_id = ann.get("photo_id")
    return {
        "id": ann["id"],
        "baby_profile_id": ann["baby_profile_id"],
        "first_name": ann.get("first_name"),
        "last_name": ann.get("last_name"),
        "gender": ann.get("gender"),
        "birth_date": bd.isoformat() if bd and hasattr(bd, "isoformat") else bd,
        "birth_time": ann.get("birth_time"),
        "weight_text": ann.get("weight_text"),
        "length_text": ann.get("length_text"),
        "photo_id": str(photo_id) if photo_id else None,
        "photo_display_url": _photo_display_url(baby_id, photo_id),
        "squish_count": ann.get("squish_count") or 0,
        "comment_count": ann.get("comment_count") or 0,
        "comments": [
            {
                "id": c["id"],
                "body": c["body"],
                "author_display_name": c["author_display_name"],
                "created_at": c["created_at"].isoformat()
                if hasattr(c["created_at"], "isoformat")
                else str(c["created_at"]),
            }
            for c in comments
        ],
    }


def fetch_announcement(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict[str, Any] | None:
    require_membership(firebase_uid, baby_profile_id)
    ann = get_announcement(baby_profile_id)
    if ann is None:
        return None
    comments = list_comments(ann["id"])
    return _serialize(ann, comments)


def _persist_announcement(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    first_name: str | None,
    last_name: str | None,
    gender: str | None,
    birth_date: date | None,
    birth_time: str | None,
    weight_text: str | None,
    length_text: str | None,
    photo_id: uuid.UUID | None,
) -> dict[str, Any]:
    validate_announcement_fields(
        gender=gender,
        birth_date=birth_date,
        birth_time=birth_time,
        first_name=first_name,
        last_name=last_name,
        weight_text=weight_text,
        length_text=length_text,
    )
    _require_baby_announcement_photo(baby_profile_id, photo_id)
    ann = upsert_announcement(
        baby_profile_id,
        firebase_uid,
        first_name=first_name,
        last_name=last_name,
        gender=gender,
        birth_date=birth_date,
        birth_time=birth_time,
        weight_text=weight_text,
        length_text=length_text,
        photo_id=photo_id,
    )
    comments = list_comments(ann["id"])
    return _serialize(ann, comments)


def save_announcement(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    first_name: str | None,
    last_name: str | None,
    gender: str | None,
    birth_date: date | None,
    birth_time: str | None,
    weight_text: str | None,
    length_text: str | None,
    photo_id: uuid.UUID | None,
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    return _persist_announcement(
        firebase_uid,
        baby_profile_id,
        first_name=first_name,
        last_name=last_name,
        gender=gender,
        birth_date=birth_date,
        birth_time=birth_time,
        weight_text=weight_text,
        length_text=length_text,
        photo_id=photo_id,
    )


def patch_announcement(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    fields: dict[str, Any],
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    existing = get_announcement(baby_profile_id) or {}
    merged = merge_announcement_patch(existing, fields)
    return _persist_announcement(
        firebase_uid,
        baby_profile_id,
        first_name=merged.get("first_name"),
        last_name=merged.get("last_name"),
        gender=merged.get("gender"),
        birth_date=merged.get("birth_date"),
        birth_time=merged.get("birth_time"),
        weight_text=merged.get("weight_text"),
        length_text=merged.get("length_text"),
        photo_id=merged.get("photo_id"),
    )


def squish_announcement(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    ann = get_announcement(baby_profile_id)
    if ann is None:
        raise LookupError("Announcement not found.")
    liked = toggle_squish(ann["id"], firebase_uid)
    ann = get_announcement(baby_profile_id)
    assert ann is not None
    return {"squished": liked, "squish_count": ann.get("squish_count") or 0}


def post_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    body: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    ann = get_announcement(baby_profile_id)
    if ann is None:
        raise LookupError("Announcement not found.")
    row = add_comment(ann["id"], firebase_uid, body)
    return {
        "id": row["id"],
        "body": row["body"],
        "created_at": row["created_at"].isoformat()
        if hasattr(row["created_at"], "isoformat")
        else str(row["created_at"]),
    }
