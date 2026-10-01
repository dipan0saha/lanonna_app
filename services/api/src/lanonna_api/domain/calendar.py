from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from lanonna_api.domain import assert_owner_membership
from lanonna_api.domain.gallery import require_membership
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.repositories.events import (
    create_event,
    delete_event,
    get_caller_rsvp,
    get_event,
    insert_event_comment,
    list_event_comments,
    list_events,
    rsvp_summary,
    soft_delete_event_comment,
    update_event,
    update_event_comment,
    upsert_rsvp,
)
from lanonna_api.repositories.users import upsert_app_user


def _author_name(row: dict[str, Any]) -> str:
    if row.get("author_display_name"):
        return row["author_display_name"]
    email = row.get("author_email") or ""
    if email and "@" in email:
        return email.split("@")[0]
    return "Family member"


def _parse_month(month: str) -> tuple[datetime, datetime]:
    year, mon = month.split("-")
    start = datetime(int(year), int(mon), 1, tzinfo=timezone.utc)
    if int(mon) == 12:
        end = datetime(int(year) + 1, 1, 1, tzinfo=timezone.utc)
    else:
        end = datetime(int(year), int(mon) + 1, 1, tzinfo=timezone.utc)
    return start, end


def _event_row_to_json(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(row["id"]),
        "title": row["title"],
        "description": row.get("description"),
        "starts_at": row["starts_at"].isoformat(),
        "ends_at": row["ends_at"].isoformat() if row.get("ends_at") else None,
        "location": row.get("location"),
        "video_call_url": row.get("video_call_url"),
        "cover_photo_id": str(row["cover_photo_id"]) if row.get("cover_photo_id") else None,
    }


def list_calendar_events(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    month: str | None = None,
    upcoming: bool = False,
) -> list[dict[str, Any]]:
    require_membership(firebase_uid, baby_profile_id)
    month_start = month_end = None
    if month:
        month_start, month_end = _parse_month(month)
    rows = list_events(
        baby_profile_id,
        month_start=month_start,
        month_end=month_end,
        upcoming_only=upcoming,
        now=datetime.now(timezone.utc),
    )
    return [_event_row_to_json(r) for r in rows]


def get_event_detail(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    row = get_event(baby_profile_id, event_id)
    if row is None:
        raise LookupError("Event not found.")
    comments = list_event_comments(event_id)
    summary = rsvp_summary(event_id)
    caller = get_caller_rsvp(event_id, firebase_uid)
    return {
        **_event_row_to_json(row),
        "rsvp_summary": summary,
        "viewer_rsvp": caller,
        "comments": [
            {
                "id": str(c["id"]),
                "body": c["body"],
                "author_display_name": _author_name(c),
                "author_firebase_uid": c["author_firebase_uid"],
                "created_at": c["created_at"].isoformat(),
                "is_mine": c["author_firebase_uid"] == firebase_uid,
            }
            for c in comments
        ],
    }


def create_calendar_event(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    title: str,
    starts_at: datetime,
    ends_at: datetime | None,
    description: str | None,
    location: str | None,
    video_call_url: str | None,
    cover_photo_id: uuid.UUID | None,
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    upsert_app_user(firebase_uid, None)
    row = create_event(
        baby_profile_id,
        firebase_uid,
        title=title,
        starts_at=starts_at,
        ends_at=ends_at,
        description=description,
        location=location,
        video_call_url=video_call_url,
        cover_photo_id=cover_photo_id,
    )
    insert_activity_event(
        baby_profile_id,
        firebase_uid,
        "event_created",
        f"New event: {row['title']}",
        payload={"event_id": str(row["id"])},
    )
    return _event_row_to_json(row)


def update_calendar_event(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    fields: dict[str, Any],
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    row = update_event(baby_profile_id, event_id, fields)
    if row is None:
        raise LookupError("Event not found.")
    return _event_row_to_json(row)


def remove_calendar_event(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
) -> None:
    assert_owner_membership(firebase_uid, baby_profile_id)
    if not delete_event(baby_profile_id, event_id):
        raise LookupError("Event not found.")


def set_rsvp(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    status: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    if status not in ("going", "maybe", "cant_go"):
        raise ValueError("Invalid RSVP status.")
    if get_event(baby_profile_id, event_id) is None:
        raise LookupError("Event not found.")
    upsert_app_user(firebase_uid, None)
    upsert_rsvp(event_id, firebase_uid, status)
    return {"status": status}


def add_event_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    body: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    if get_event(baby_profile_id, event_id) is None:
        raise LookupError("Event not found.")
    if not body.strip():
        raise ValueError("Comment body required.")
    upsert_app_user(firebase_uid, None)
    c = insert_event_comment(event_id, firebase_uid, body)
    return {
        "id": str(c["id"]),
        "body": c["body"],
        "created_at": c["created_at"].isoformat(),
    }


def edit_event_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
    body: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    if not body.strip():
        raise ValueError("Comment body required.")
    row = update_event_comment(event_id, comment_id, firebase_uid, body)
    if row is None:
        raise LookupError("Comment not found.")
    return {"id": str(row["id"]), "body": row["body"]}


def delete_event_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
) -> None:
    require_membership(firebase_uid, baby_profile_id)
    if not soft_delete_event_comment(event_id, comment_id, firebase_uid):
        raise LookupError("Comment not found.")
