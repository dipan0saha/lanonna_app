from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from lanonna_api.domain.errors import ErrorCode, InvalidInputError
from lanonna_api.domain import assert_owner_membership
from lanonna_api.domain.catalog_suggestion_ids import normalize_catalog_suggestion_id
from lanonna_api.domain.url_validation import normalize_optional_http_url
from lanonna_api.domain.content_permissions import (
    member_comment_to_json,
    member_content_can_delete,
    member_content_can_edit,
)
from lanonna_api.domain.gallery import require_membership
from lanonna_activity_copy import ActivityEventType, NotificationKind
from lanonna_activity_copy import params
from lanonna_api.domain.notifications import (
    FanOutSpec,
    NotificationChannel,
    NotifyUserSpec,
    safe_enqueue_notify_user,
    safe_enqueue_fan_out,
)
from lanonna_api.pagination import offset_page_from_extra_row
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.db import read_scope
from lanonna_api.domain.media_urls import signed_display_url
from lanonna_api.domain.photo_lifecycle import purge_event_cover_photo_if_unreferenced
from lanonna_api.domain.users_display import (
    author_display_name_from_row,
    rsvp_display_name_from_row,
)
from lanonna_api.repositories.events import (
    LIST_EVENTS_MAX_ROWS,
    PAST_EVENTS_PAGE_SIZE,
    catalog_suggestion_claimed,
    create_event,
    delete_event,
    get_caller_rsvp,
    get_event,
    get_event_comment,
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
from lanonna_api.domain.date_validation import validate_event_time_range
from lanonna_api.repositories.photos import get_photo_for_baby


def _require_baby_cover_photo(
    baby_profile_id: uuid.UUID,
    cover_photo_id: uuid.UUID | None,
) -> None:
    if cover_photo_id is None:
        return
    if get_photo_for_baby(baby_profile_id, cover_photo_id) is None:
        raise ValueError("Cover photo must belong to this baby profile.")


def _parse_month(month: str) -> tuple[datetime, datetime]:
    """UTC calendar month (legacy ``month=YYYY-MM`` query; app builds before #68)."""
    year_s, mon_s = month.split("-")
    year, mon = int(year_s), int(mon_s)
    start = datetime(year, mon, 1, tzinfo=timezone.utc)
    if mon == 12:
        end = datetime(year + 1, 1, 1, tzinfo=timezone.utc)
    else:
        end = datetime(year, mon + 1, 1, tzinfo=timezone.utc)
    return start, end


# A local calendar month is at most 31 days plus a DST hour; leave a little slack.
MAX_EVENT_LIST_WINDOW = timedelta(days=32)


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def resolve_event_list_window(
    month: str | None,
    starts_from: datetime | None,
    starts_before: datetime | None,
) -> tuple[datetime | None, datetime | None]:
    """``[start, end)`` filter for the event list.

    The app sends ``starts_from`` / ``starts_before``: the instants of its local
    month start and next month start, so DST changes inside the month are
    handled by the device's own time zone rules (#68). ``month`` alone is the
    legacy UTC month.
    """
    if starts_from is None and starts_before is None:
        return _parse_month(month) if month else (None, None)
    if month or starts_from is None or starts_before is None:
        raise InvalidInputError(
            ErrorCode.INVALID_REQUEST,
            "Send both starts_from and starts_before, without month.",
        )
    start, end = _as_utc(starts_from), _as_utc(starts_before)
    if end <= start or end - start > MAX_EVENT_LIST_WINDOW:
        raise InvalidInputError(
            ErrorCode.INVALID_REQUEST,
            "starts_before must be after starts_from and at most 32 days later.",
        )
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
    past: bool = False,
    offset: int = 0,
    limit: int | None = None,
    starts_from: datetime | None = None,
    starts_before: datetime | None = None,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    if upcoming and past:
        raise ValueError("Cannot request both upcoming and past events.")
    month_start, month_end = resolve_event_list_window(month, starts_from, starts_before)
    if past:
        page_size = limit or PAST_EVENTS_PAGE_SIZE
        if offset < 0:
            raise ValueError("offset must be non-negative.")
        rows = list_events(
            baby_profile_id,
            month_start=month_start,
            month_end=month_end,
            upcoming_only=False,
            past_only=True,
            now=datetime.now(timezone.utc),
            limit=page_size + 1,
            offset=offset,
        )
        page = offset_page_from_extra_row(
            rows, offset=offset, limit=page_size
        )
        page["items"] = [_event_row_to_json(r) for r in page["items"]]
        return page
    rows = list_events(
        baby_profile_id,
        month_start=month_start,
        month_end=month_end,
        upcoming_only=upcoming,
        past_only=False,
        now=datetime.now(timezone.utc),
        limit=LIST_EVENTS_MAX_ROWS + 1,
    )
    # Month and upcoming views are naturally bounded and load in one page;
    # the same envelope reports has_more if the safety cap is ever hit.
    page = offset_page_from_extra_row(rows, offset=0, limit=LIST_EVENTS_MAX_ROWS)
    page["items"] = [_event_row_to_json(r) for r in page["items"]]
    return page


def get_event_detail(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
) -> dict[str, Any]:
    with read_scope():
        membership = require_membership(firebase_uid, baby_profile_id)
        row = get_event(baby_profile_id, event_id)
        if row is None:
            raise LookupError("Event not found.")
        comments = list_event_comments(event_id)
        summary = rsvp_summary(event_id)
        caller = get_caller_rsvp(event_id, firebase_uid)
        cover_photo_id = row.get("cover_photo_id")
        cover = (
            get_photo_for_baby(baby_profile_id, cover_photo_id) if cover_photo_id else None
        )
        rsvps = list_rsvps_for_event(event_id)
    cover_display_url = None
    if cover and cover.get("status") == "ready":
        cover_display_url = signed_display_url(cover.get("display_path"))
    return {
        **_event_row_to_json(row),
        "cover_photo_display_url": cover_display_url,
        "rsvp_summary": summary,
        "viewer_rsvp": caller,
        "rsvp_attendees": [
            {
                "firebase_uid": r["firebase_uid"],
                "status": r["status"],
                "display_name": rsvp_display_name_from_row(r),
            }
            for r in rsvps
        ],
        "comments": [
            member_comment_to_json(
                c, firebase_uid, membership, author_display_name_from_row(c)
            )
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
        raise InvalidInputError(ErrorCode.ALREADY_ON_CALENDAR, "This suggestion is already on the calendar.")
    video_call_url = normalize_optional_http_url(video_call_url)
    _require_baby_cover_photo(baby_profile_id, cover_photo_id)
    validate_event_time_range(starts_at, ends_at)
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
        ActivityEventType.EVENT_CREATED,
        {params.EVENT_TITLE: row["title"]},
        payload={"event_id": str(row["id"])},
    )
    safe_enqueue_fan_out(
        FanOutSpec(
            baby_profile_id=baby_profile_id,
            kind=NotificationKind.EVENT_CREATED,
            params={params.EVENT_TITLE: row["title"]},
            deep_link=f"/calendar/event/{row['id']}",
            actor_firebase_uid=firebase_uid,
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
    if "video_call_url" in fields:
        fields["video_call_url"] = normalize_optional_http_url(
            fields["video_call_url"]
        )
    existing = get_event(baby_profile_id, event_id)
    if existing is None:
        raise LookupError("Event not found.")
    previous_cover_id = existing.get("cover_photo_id")
    if "cover_photo_id" in fields:
        _require_baby_cover_photo(baby_profile_id, fields.get("cover_photo_id"))
    if "starts_at" in fields or "ends_at" in fields:
        starts_at = fields["starts_at"] if "starts_at" in fields else existing["starts_at"]
        ends_at = fields["ends_at"] if "ends_at" in fields else existing.get("ends_at")
        validate_event_time_range(starts_at, ends_at)
    row = update_event(baby_profile_id, event_id, fields)
    if row is None:
        raise LookupError("Event not found.")
    if "cover_photo_id" in fields:
        new_cover_id = fields.get("cover_photo_id")
        if previous_cover_id != new_cover_id:
            purge_event_cover_photo_if_unreferenced(previous_cover_id)
    return _event_row_to_json(row)


def remove_calendar_event(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    event_id: uuid.UUID,
) -> None:
    assert_owner_membership(firebase_uid, baby_profile_id)
    existing = get_event(baby_profile_id, event_id)
    if existing is None:
        raise LookupError("Event not found.")
    cover_photo_id = existing.get("cover_photo_id")
    if not delete_event(baby_profile_id, event_id):
        raise LookupError("Event not found.")
    purge_event_cover_photo_if_unreferenced(cover_photo_id)


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
    upsert_rsvp(event_id, firebase_uid, status)
    creator = event.get("created_by_firebase_uid")
    if creator and creator != firebase_uid:
        safe_enqueue_notify_user(
            NotifyUserSpec(
                firebase_uid=creator,
                kind=NotificationKind.EVENT_RSVP,
                params={params.EVENT_TITLE: event["title"], params.RSVP_STATUS: status},
                deep_link=f"/calendar/event/{event_id}",
                actor_firebase_uid=firebase_uid,
                baby_profile_id=baby_profile_id,
                notification_channel=NotificationChannel.CALENDAR,
            )
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
        raise InvalidInputError(ErrorCode.COMMENT_REQUIRED, "Comment body required.")
    c = insert_event_comment(event_id, firebase_uid, body)
    creator = event.get("created_by_firebase_uid")
    if creator and creator != firebase_uid:
        safe_enqueue_notify_user(
            NotifyUserSpec(
                firebase_uid=creator,
                kind=NotificationKind.EVENT_COMMENTED,
                params={params.EVENT_TITLE: event["title"]},
                deep_link=f"/calendar/event/{event_id}",
                actor_firebase_uid=firebase_uid,
                baby_profile_id=baby_profile_id,
                notification_channel=NotificationChannel.COMMENTS,
            )
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
    membership = require_membership(firebase_uid, baby_profile_id)
    event = get_event(baby_profile_id, event_id)
    if event is None:
        raise LookupError("Event not found.")
    comment = get_event_comment(event_id, comment_id)
    if comment is None:
        raise LookupError("Comment not found.")
    if not member_content_can_delete(
        firebase_uid, membership, comment["author_firebase_uid"]
    ):
        raise PermissionError("Cannot delete this comment.")
    if not soft_delete_event_comment(event_id, comment_id):
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
        raise InvalidInputError(ErrorCode.COMMENT_REQUIRED, "Comment body required.")
    comment = get_event_comment(event_id, comment_id)
    if comment is None:
        raise LookupError("Comment not found.")
    if not member_content_can_edit(firebase_uid, comment["author_firebase_uid"]):
        raise PermissionError("Cannot edit this comment.")
    updated = update_event_comment(
        event_id,
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
