from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from lanonna_api.domain import assert_owner_membership
from lanonna_api.domain.catalog_suggestion_ids import normalize_catalog_suggestion_id
from lanonna_api.domain.gallery import require_membership
from lanonna_api.domain.notification_copy import actor_display_name
from lanonna_api.domain.notifications import (
    FanOutSpec,
    NotificationChannel,
    safe_enqueue_notify_user,
    safe_enqueue_fan_out,
)
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.domain.media_urls import signed_display_url
from lanonna_api.domain.users_display import author_display_name_from_row
from lanonna_api.repositories.events import (
    catalog_suggestion_claimed,
    create_event,
    delete_event,
    get_caller_rsvp,
    get_event,
    insert_event_comment,
    list_event_comments,
    list_events,
    list_rsvps_for_event,
    rsvp_summary,
    soft_delete_event_comment,
    update_event,
    update_event_comment,
    upsert_rsvp,
)
from lanonna_api.repositories.photos import get_photo_for_baby
from lanonna_api.repositories.users import upsert_app_user


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
        "catalog_suggestion_id": row.get("catalog_suggestion_id"),
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
    cover_photo_id = row.get("cover_photo_id")
    cover_display_url = None
    if cover_photo_id:
        photo = get_photo_for_baby(baby_profile_id, cover_photo_id)
        if photo and photo.get("status") == "ready":
            cover_display_url = signed_display_url(photo.get("display_path"))
    rsvps = list_rsvps_for_event(event_id)
    return {
        **_event_row_to_json(row),
        "cover_photo_display_url": cover_display_url,
        "rsvp_summary": summary,
        "viewer_rsvp": caller,
        "rsvp_attendees": [
            {
                "firebase_uid": r["firebase_uid"],
                "status": r["status"],
                "display_name": author_display_name_from_row(r),
            }
            for r in rsvps
        ],
        "comments": [
            {
                "id": str(c["id"]),
                "body": c["body"],
                "author_display_name": author_display_name_from_row(c),
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
    catalog_suggestion_id: str | None = None,
) -> dict[str, Any]:
    assert_owner_membership(firebase_uid, baby_profile_id)
    catalog_id = normalize_catalog_suggestion_id(catalog_suggestion_id)
    if catalog_id and catalog_suggestion_claimed(baby_profile_id, catalog_id):
        raise ValueError("This suggestion is already on the calendar.")
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
        catalog_suggestion_id=catalog_id,
    )
    insert_activity_event(
        baby_profile_id,
        firebase_uid,
        "event_created",
        f"New event: {row['title']}",
        payload={"event_id": str(row["id"])},
    )
    safe_enqueue_fan_out(
        FanOutSpec(
            baby_profile_id=baby_profile_id,
            title="New event",
            body=f'"{row["title"]}" was added to the calendar',
            deep_link=f"/calendar/event/{row['id']}",
            exclude_firebase_uid=firebase_uid,
            notification_channel=NotificationChannel.CALENDAR,
        )
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
    event = get_event(baby_profile_id, event_id)
    if event is None:
        raise LookupError("Event not found.")
    upsert_app_user(firebase_uid, None)
    upsert_rsvp(event_id, firebase_uid, status)
    creator = event.get("created_by_firebase_uid")
    if creator and creator != firebase_uid:
        actor = actor_display_name(firebase_uid)
        safe_enqueue_notify_user(
            creator,
            title="New RSVP",
            body=f'{actor} responded "{status}" to {event["title"]}',
            deep_link=f"/calendar/event/{event_id}",
            baby_profile_id=baby_profile_id,
            notification_channel=NotificationChannel.CALENDAR,
        )
    return {"status": status}


def add_event_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    body: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    event = get_event(baby_profile_id, event_id)
    if event is None:
        raise LookupError("Event not found.")
    if not body.strip():
        raise ValueError("Comment body required.")
    upsert_app_user(firebase_uid, None)
    c = insert_event_comment(event_id, firebase_uid, body)
    creator = event.get("created_by_firebase_uid")
    if creator and creator != firebase_uid:
        actor = actor_display_name(firebase_uid)
        safe_enqueue_notify_user(
            creator,
            title="New comment",
            body=f'{actor} commented on "{event["title"]}"',
            deep_link=f"/calendar/event/{event_id}",
            baby_profile_id=baby_profile_id,
            notification_channel=NotificationChannel.COMMENTS,
        )
    return {
        "id": str(c["id"]),
        "body": c["body"],
        "created_at": c["created_at"].isoformat(),
    }


def delete_event_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
) -> None:
    require_membership(firebase_uid, baby_profile_id)
    if not soft_delete_event_comment(event_id, comment_id, firebase_uid):
        raise LookupError("Comment not found.")


def edit_event_comment(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
    comment_id: uuid.UUID,
    body: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    event = get_event(baby_profile_id, event_id)
    if event is None:
        raise LookupError("Event not found.")
    if not body.strip():
        raise ValueError("Comment body required.")
    updated = update_event_comment(event_id, comment_id, firebase_uid, body)
    if updated is None:
        raise LookupError("Comment not found.")
    return {
        "id": str(updated["id"]),
        "body": updated["body"],
        "updated_at": updated["updated_at"].isoformat(),
    }
