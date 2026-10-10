from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Any, Literal

from lanonna_api.domain.activity_copy import (
    GALLERY_ACTIVITY_EVENT_TYPES,
    serialize_activity_item,
)
from lanonna_api.repositories.activity_events import (
    count_name_suggestions,
    insert_activity_event,
    list_recent_for_baby,
)
from lanonna_api.domain.media_urls import signed_display_url, signed_thumb_url
from lanonna_api.domain.membership_access import require_active_membership
from lanonna_api.repositories.babies import (
    get_baby_for_owner,
    update_baby_for_owner,
)
from lanonna_api.repositories.events import get_caller_rsvp, list_events
from lanonna_api.repositories.notifications import list_notifications_for_user
from lanonna_api.repositories.photos import get_photo_for_baby, list_photos_for_baby
from lanonna_api.repositories.fun import (
    birthdate_vote_histogram,
    count_gender_votes,
    gender_vote_totals,
    list_name_suggestions,
)
from lanonna_api.repositories.home_counts import (
    count_events,
    count_follower_memberships,
    count_open_registry_items,
    count_photos_for_baby,
    count_registry_items,
    count_sent_invitations,
    list_new_followers,
)
from lanonna_api.repositories.invitations import list_invitations_for_baby
from lanonna_api.repositories.announcements import get_announcement
from lanonna_api.repositories.registry import (
    list_open_registry_highlights,
    list_recent_registry_purchases,
)
from lanonna_api.repositories.system_announcements import list_active_for_user
from lanonna_api.domain.date_validation import (
    utc_today as _utc_today,
    validate_actual_birth_date,
)
from lanonna_api.domain.notifications import (
    FanOutSpec,
    NotificationChannel,
    safe_enqueue_fan_out,
)
_BIRTH_WELCOME_VISIBLE_DAYS = 7


def _display_url_for_photo(baby_profile_id: uuid.UUID, photo_id: uuid.UUID | None) -> str | None:
    if photo_id is None:
        return None
    row = get_photo_for_baby(baby_profile_id, photo_id)
    if row is None:
        return None
    return signed_display_url(row.get("display_path"))


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
    if not is_owner or (baby.get("lifecycle_status") or "") != "born":
        return None
    birth = _parse_date(baby.get("actual_birth_date"))
    if birth is None:
        return None
    days_since = (_utc_today() - birth).days
    if days_since > _BIRTH_WELCOME_VISIBLE_DAYS:
        return None
    welcome_until = birth + timedelta(days=_BIRTH_WELCOME_VISIBLE_DAYS)
    baby_name = baby.get("name") or "Baby"
    ann = get_announcement(baby_profile_id)
    announcement_preview = None
    if ann:
        photo_id = ann.get("photo_id")
        announcement_preview = {
            "announcement_id": str(ann["id"]),
            "first_name": ann.get("first_name"),
            "last_name": ann.get("last_name"),
            "photo_display_url": _display_url_for_photo(baby_profile_id, photo_id),
        }
    return {
        "baby_name": baby_name,
        "days_since_birth": days_since,
        "welcome_visible_until": welcome_until.isoformat(),
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
        limit=limit,
        offset=offset,
        event_types=event_types,
    )
    return {
        "items": [serialize_activity_item(item) for item in rows],
        "limit": limit,
        "offset": offset,
        "has_more": len(rows) == limit,
    }


def _build_home_teasers(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any]:
    photos = list_photos_for_baby(baby_profile_id, ready_only=True, limit=4)
    recent_photos = [
        {
            "id": str(p["id"]),
            "thumb_url": signed_thumb_url(p.get("thumb_path")),
        }
        for p in photos
        if p.get("thumb_path")
    ]
    fav_rows = list_photos_for_baby(
        baby_profile_id, ready_only=True, limit=4, sort="favorites"
    )
    favorite_photos = [
        {
            "id": str(p["id"]),
            "thumb_url": signed_thumb_url(p.get("thumb_path")),
            "squish_count": p.get("squish_count", 0),
        }
        for p in fav_rows
        if p.get("thumb_path")
    ]
    rsvp_reminders: list[dict[str, Any]] = []
    for ev in list_events(baby_profile_id, upcoming_only=True):
        if get_caller_rsvp(ev["id"], firebase_uid) is not None:
            continue
        rsvp_reminders.append(
            {
                "id": str(ev["id"]),
                "title": ev["title"],
                "starts_at": ev["starts_at"].isoformat()
                if hasattr(ev["starts_at"], "isoformat")
                else str(ev["starts_at"]),
            }
        )
        if len(rsvp_reminders) >= 3:
            break
    notifs = list_notifications_for_user(firebase_uid, limit=3, unread_only=True)
    upcoming_events = [
        _serialize_upcoming_event(ev)
        for ev in list_events(baby_profile_id, upcoming_only=True)[:3]
    ]
    registry_highlights = [
        {
            "id": str(r["id"]),
            "name": r["name"],
            "priority": int(r.get("priority") or 0),
        }
        for r in list_open_registry_highlights(baby_profile_id, limit=3)
    ]
    recent_purchases = []
    for row in list_recent_registry_purchases(baby_profile_id):
        purchased_at = row.get("purchased_at")
        recent_purchases.append(
            {
                "item_id": str(row["item_id"]),
                "item_name": row["item_name"],
                "purchaser_display_name": row.get("purchaser_display_name"),
                "purchased_at": purchased_at.isoformat()
                if hasattr(purchased_at, "isoformat")
                else str(purchased_at),
            }
        )
    return {
        "recent_photos": recent_photos,
        "favorite_photos": favorite_photos,
        "registry_open_count": count_open_registry_items(baby_profile_id),
        "registry_highlights": registry_highlights,
        "recent_registry_purchases": recent_purchases,
        "upcoming_events": upcoming_events,
        "rsvp_reminders": rsvp_reminders,
        "notification_preview": [
            {
                "id": str(n["id"]),
                "title": n["title"],
                "body": n["body"],
                "deep_link": n.get("deep_link"),
                "baby_profile_id": str(n["baby_profile_id"])
                if n.get("baby_profile_id")
                else None,
                "created_at": n["created_at"].isoformat()
                if hasattr(n["created_at"], "isoformat")
                else str(n["created_at"]),
            }
            for n in notifs
        ],
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

    baby_name = baby.get("name") or "Baby"
    record_arrival_event = baby.get("lifecycle_status") == "expecting"
    fields: dict[str, Any] = {
        "lifecycle_status": "born",
        "actual_birth_date": actual_birth_date,
    }
    if extra_fields:
        for key, value in extra_fields.items():
            if value is not None and key not in ("lifecycle_status", "actual_birth_date"):
                fields[key] = value

    row = update_baby_for_owner(firebase_uid, baby_profile_id, fields)
    if row is None:
        raise PermissionError("Owner access required for this baby profile.")

    if record_arrival_event:
        insert_activity_event(
            baby_profile_id,
            firebase_uid,
            "baby_arrived",
            f"{baby_name} has arrived!",
            {"actual_birth_date": actual_birth_date.isoformat()},
        )

    result = dict(row)
    result["role"] = "owner"
    result["relationship_label"] = None
    if record_arrival_event:
        safe_enqueue_fan_out(
            FanOutSpec(
                baby_profile_id=baby_profile_id,
                title="Baby has arrived!",
                body=f"{baby_name} has arrived - see the announcement",
                deep_link=f"/baby/{baby_profile_id}/announcement",
                exclude_firebase_uid=firebase_uid,
                notification_channel=NotificationChannel.CALENDAR,
            )
        )
    return result


def build_home_summary(
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

    suggestion_count = count_name_suggestions(baby_profile_id)
    vote_count = count_gender_votes(baby_profile_id)
    recent = list_recent_for_baby(baby_profile_id, limit=10)
    totals = gender_vote_totals(baby_profile_id)

    top_name = None
    names = list_name_suggestions(baby_profile_id)
    if names:
        top = names[0]
        top_name = {
            "suggested_name": top["suggested_name"],
            "like_count": int(top.get("like_count") or 0),
        }

    top_birthdate = None
    hist = birthdate_vote_histogram(baby_profile_id)
    if hist:
        d = hist[0]["predicted_birth_date"]
        top_birthdate = d.isoformat() if hasattr(d, "isoformat") else str(d)

    next_up = None
    upcoming = list_events(baby_profile_id, upcoming_only=True)
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
        has_registry = count_registry_items(baby_profile_id) > 0
        has_invite = (
            count_sent_invitations(baby_profile_id) > 0
            or count_follower_memberships(baby_profile_id) > 0
        )
        has_photo = count_photos_for_baby(baby_profile_id) > 0
        has_event = count_events(baby_profile_id) > 0
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
            for inv in list_invitations_for_baby(baby_profile_id)
            if inv.get("status") == "pending"
        ][:5]

    return {
        "baby_profile_id": baby_profile_id,
        "lifecycle_status": lifecycle,
        "days_to_due": days_to_due,
        "birth_welcome": _build_birth_welcome(baby, baby_profile_id, is_owner),
        "family_insight": {
            "name_suggestion_count": suggestion_count,
            "vote_count": vote_count,
            "gender_totals": totals,
            "top_name": top_name,
            "top_birthdate_guess": top_birthdate,
        },
        "next_up_event": next_up,
        "getting_started": getting_started,
        "system_announcements": system_announcements,
        "new_followers": new_followers,
        "invite_status": invite_status,
        "teasers": _build_home_teasers(firebase_uid, baby_profile_id),
        "recent_activity": [serialize_activity_item(item) for item in recent],
    }
