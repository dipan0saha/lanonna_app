from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import Any, Literal

from lanonna_activity_copy import (
    GALLERY_ACTIVITY_EVENT_TYPES,
    ActivityEventType,
    NotificationKind,
    baby_name_params,
)
from lanonna_api.domain.activity_feed import serialize_activity_item
from lanonna_api.db import read_scope
from lanonna_api.repositories.activity_events import (
    insert_activity_event,
    list_recent_for_baby,
)
from lanonna_api.domain.announcement import announcement_photo_display_url
from lanonna_api.domain.birthdate_vote_window import (
    birthdate_vote_shown_window,
    expected_due_date,
)
from lanonna_api.domain.media_urls import signed_thumb_urls
from lanonna_api.domain.membership_access import require_active_membership
from lanonna_api.repositories.babies import (
    get_baby_for_owner,
    update_baby_for_owner,
)
from lanonna_api.repositories.events import list_events
from lanonna_api.repositories.photos import list_photos_for_baby
from lanonna_api.repositories.fun import list_name_suggestions
from lanonna_api.repositories.home_counts import home_summary_counts, list_new_followers
from lanonna_api.repositories.invitations import list_invitations_for_baby
from lanonna_api.repositories.announcements import get_announcement
from lanonna_api.repositories.system_announcements import list_active_for_user
from lanonna_api.domain.date_validation import (
    utc_today as _utc_today,
    validate_actual_birth_date,
)
from lanonna_api.domain.fun_closed import fun_closed_flags
from lanonna_api.pagination import offset_page_from_extra_row
from lanonna_api.domain.notifications import (
    FanOutSpec,
    NotificationChannel,
    safe_enqueue_fan_out,
)
_BIRTH_WELCOME_VISIBLE_DAYS = 7
# Home shows the next few upcoming events, the newest pending invites and the
# newest photos; each is read with a LIMIT, never loaded whole.
_HOME_UPCOMING_EVENTS = 3
_HOME_PENDING_INVITES = 5
_HOME_TEASER_PHOTOS = 4
_HOME_RECENT_ACTIVITY = 10


def _parse_date(value: Any) -> date | None:
    if value is None:
        return None
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value))


def _serialize_upcoming_event(ev: dict[str, Any]) -> dict[str, Any]:
    starts = ev["starts_at"]
    return {
        "id": str(ev["id"]),
        "title": ev["title"],
        "starts_at": starts.isoformat() if hasattr(starts, "isoformat") else str(starts),
        "location": ev.get("location"),
    }


def _build_birth_welcome(
    baby: dict[str, Any],
    baby_profile_id: uuid.UUID,
    is_owner: bool,
) -> dict[str, Any] | None:
    if (baby.get("lifecycle_status") or "") != "born":
        return None
    birth = _parse_date(baby.get("actual_birth_date"))
    if birth is None:
        return None
    days_since = (_utc_today() - birth).days
    if days_since > _BIRTH_WELCOME_VISIBLE_DAYS:
        return None
    welcome_until = birth + timedelta(days=_BIRTH_WELCOME_VISIBLE_DAYS)
    ann = get_announcement(baby_profile_id)
    announcement_preview = None
    weight_text = None
    if ann:
        photo_id = ann.get("photo_id")
        weight_text = ann.get("weight_text")
        announcement_preview = {
            "announcement_id": str(ann["id"]),
            "first_name": ann.get("first_name"),
            "last_name": ann.get("last_name"),
            "photo_display_url": announcement_photo_display_url(baby_profile_id, photo_id),
        }
    birth_iso = birth.isoformat()
    everyone_notified = is_owner and ann is not None
    return {
        "baby_name": baby.get("name"),
        "days_since_birth": days_since,
        "welcome_visible_until": welcome_until.isoformat(),
        "birth_date": birth_iso,
        "weight_text": weight_text,
        "everyone_notified": everyone_notified,
        "announcement": announcement_preview,
    }


def list_activity_events(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    *,
    limit: int = 20,
    offset: int = 0,
    scope: Literal["all", "gallery"] = "all",
) -> dict[str, Any]:
    require_active_membership(firebase_uid, baby_profile_id)
    limit = min(max(limit, 1), 50)
    offset = max(offset, 0)
    event_types = tuple(GALLERY_ACTIVITY_EVENT_TYPES) if scope == "gallery" else None
    rows = list_recent_for_baby(
        baby_profile_id,
        limit=limit + 1,
        offset=offset,
        event_types=event_types,
    )
    page = offset_page_from_extra_row(rows, offset=offset, limit=limit)
    page["items"] = [serialize_activity_item(item) for item in page["items"]]
    return page


def _build_home_teasers(
    baby_profile_id: uuid.UUID,
    upcoming: list[dict[str, Any]],
) -> dict[str, Any]:
    """Teaser strip: newest ready photos (thumbs signed as one batch) and ``upcoming``."""
    photos = [
        p
        for p in list_photos_for_baby(
            baby_profile_id, ready_only=True, limit=_HOME_TEASER_PHOTOS
        )
        if p.get("thumb_path")
    ]
    thumb_urls = signed_thumb_urls([p["thumb_path"] for p in photos])
    return {
        "recent_photos": [
            {"id": str(p["id"]), "thumb_url": url} for p, url in zip(photos, thumb_urls)
        ],
        "upcoming_events": [_serialize_upcoming_event(ev) for ev in upcoming],
    }


def announce_arrival(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    actual_birth_date: date,
    extra_fields: dict[str, Any] | None = None,
) -> dict[str, Any]:
    validate_actual_birth_date(actual_birth_date)

    baby = get_baby_for_owner(firebase_uid, baby_profile_id)
    if baby is None:
        raise PermissionError("Owner access required for this baby profile.")

    record_arrival_event = baby.get("lifecycle_status") == "expecting"
    fields: dict[str, Any] = {
        "lifecycle_status": "born",
        "actual_birth_date": actual_birth_date,
    }
    if extra_fields:
        for key, value in extra_fields.items():
            if key not in ("lifecycle_status", "actual_birth_date"):
                fields[key] = value

    row = update_baby_for_owner(firebase_uid, baby_profile_id, fields)
    if row is None:
        raise PermissionError("Owner access required for this baby profile.")

    if record_arrival_event:
        arrival_params = baby_name_params(row.get("name"))
        insert_activity_event(
            baby_profile_id,
            firebase_uid,
            ActivityEventType.BABY_ARRIVED,
            arrival_params,
            {"actual_birth_date": actual_birth_date.isoformat()},
        )
        safe_enqueue_fan_out(
            FanOutSpec(
                baby_profile_id=baby_profile_id,
                kind=NotificationKind.BABY_ARRIVED,
                params=arrival_params,
                deep_link=f"/baby/{baby_profile_id}/announcement",
                actor_firebase_uid=firebase_uid,
                exclude_firebase_uid=firebase_uid,
                notification_channel=NotificationChannel.CALENDAR,
            )
        )
    return row


def build_home_summary(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any]:
    """Home payload: one read-only connection, one bounded query per section."""
    with read_scope():
        return _build_home_summary(firebase_uid, baby_profile_id)


def _build_home_summary(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any]:
    baby = require_active_membership(firebase_uid, baby_profile_id)

    is_owner = baby.get("role") == "owner"

    days_to_due = None
    if baby.get("lifecycle_status") == "expecting" and baby.get("expected_birth_date"):
        due = baby["expected_birth_date"]
        if hasattr(due, "isoformat"):
            due_date = due
        else:
            due_date = date.fromisoformat(str(due))
        days_to_due = (due_date - _utc_today()).days

    counts = home_summary_counts(
        baby_profile_id,
        birthdate_window=birthdate_vote_shown_window(expected_due_date(baby)),
    )
    suggestion_count = counts["name_suggestion_count"]
    vote_count = counts["vote_count"]
    totals = {"male": counts["male_votes"], "female": counts["female_votes"]}
    recent = list_recent_for_baby(baby_profile_id, limit=_HOME_RECENT_ACTIVITY)

    top_name = None
    names = list_name_suggestions(baby_profile_id, limit=1)
    if names:
        top = names[0]
        top_name = {
            "suggested_name": top["suggested_name"],
            "like_count": int(top.get("like_count") or 0),
        }

    top_birthdate = None
    if counts["top_birthdate_guess"] is not None:
        d = counts["top_birthdate_guess"]
        top_birthdate = d.isoformat() if hasattr(d, "isoformat") else str(d)

    # One read feeds both "next up" and the teaser strip.
    upcoming = list_events(
        baby_profile_id, upcoming_only=True, limit=_HOME_UPCOMING_EVENTS
    )
    next_up = None
    if upcoming:
        ev = upcoming[0]
        next_up = {
            "id": ev["id"],
            "title": ev["title"],
            "starts_at": ev["starts_at"],
            "location": ev.get("location"),
        }

    getting_started = None
    lifecycle = baby.get("lifecycle_status") or "expecting"
    if is_owner and lifecycle == "expecting":
        has_profile = bool((baby.get("name") or "").strip()) and baby.get(
            "expected_birth_date"
        ) is not None
        has_registry = counts["has_registry_item"]
        has_invite = counts["has_invitation"] or counts["has_follower"]
        has_photo = counts["has_photo"]
        has_event = counts["has_event"]
        tasks = [
            {
                "id": "baby_profile",
                "label": "Set up baby profile",
                "done": has_profile,
                "deep_link": f"/baby/{baby_profile_id}/edit",
            },
            {
                "id": "registry_item",
                "label": "Add a registry item",
                "done": has_registry,
                "deep_link": "/registry/item/create",
            },
            {
                "id": "invite_family",
                "label": "Invite family & friends",
                "done": has_invite,
                "deep_link": "/invite-family",
            },
            {
                "id": "first_photo",
                "label": "Upload your first photo",
                "done": has_photo,
                "deep_link": "/gallery",
            },
            {
                "id": "first_event",
                "label": "Create your first event",
                "done": has_event,
                "deep_link": "/calendar/event/create",
            },
        ]
        done_count = sum(1 for t in tasks if t["done"])
        getting_started = {
            "completed_count": done_count,
            "total": len(tasks),
            "tasks": tasks,
        }

    role = baby.get("role") or "follower"
    system_announcements = [
        {
            "id": str(a["id"]),
            "title": a["title"],
            "body": a["body"],
            "cta_label": a.get("cta_label"),
            "cta_deep_link": a.get("cta_deep_link"),
        }
        for a in list_active_for_user(firebase_uid, membership_role=role)
    ]

    new_followers = None
    invite_status = None
    if is_owner:
        new_followers = [
            {
                "firebase_uid": row["firebase_uid"],
                "display_name": row["display_name"],
                "joined_at": row["joined_at"].isoformat()
                if hasattr(row["joined_at"], "isoformat")
                else str(row["joined_at"]),
            }
            for row in list_new_followers(baby_profile_id)
        ]
        invite_status = [
            {
                "id": str(inv["id"]),
                "invitee_email": inv["invitee_email"],
                "status": inv["status"],
                "created_at": inv["created_at"].isoformat()
                if hasattr(inv["created_at"], "isoformat")
                else str(inv["created_at"]),
            }
            for inv in list_invitations_for_baby(
                baby_profile_id, status="pending", limit=_HOME_PENDING_INVITES
            )
        ]

    closed = fun_closed_flags(baby)
    show_rich_insight = vote_count > 0 or int((top_name or {}).get("like_count") or 0) > 0

    return {
        "baby_profile_id": baby_profile_id,
        "lifecycle_status": lifecycle,
        "names_closed": closed["names_closed"],
        "predictions_closed": closed["predictions_closed"],
        "days_to_due": days_to_due,
        "birth_welcome": _build_birth_welcome(baby, baby_profile_id, is_owner),
        "family_insight": {
            "name_suggestion_count": suggestion_count,
            "vote_count": vote_count,
            "gender_totals": totals,
            "top_name": top_name,
            "top_birthdate_guess": top_birthdate,
            "show_rich_insight": show_rich_insight,
        },
        "next_up_event": next_up,
        "getting_started": getting_started,
        "system_announcements": system_announcements,
        "new_followers": new_followers,
        "invite_status": invite_status,
        "teasers": _build_home_teasers(baby_profile_id, upcoming),
        "recent_activity": [serialize_activity_item(item) for item in recent],
    }
