from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from typing import Any

from lanonna_api.db import get_connection
from lanonna_api.repositories.activity_events import (
    count_name_suggestions,
    insert_activity_event,
    list_recent_for_baby,
)
from lanonna_api.repositories.babies import get_baby_for_owner, get_baby_membership
from lanonna_api.repositories.events import list_events
from lanonna_api.repositories.fun import (
    birthdate_vote_histogram,
    count_gender_votes,
    gender_vote_totals,
    list_name_suggestions,
)
from lanonna_api.repositories.home_counts import (
    count_events,
    count_follower_memberships,
    count_photos_for_baby,
    count_registry_items,
    count_sent_invitations,
)


def _utc_today() -> date:
    return datetime.now(timezone.utc).date()


def announce_arrival(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    actual_birth_date: date,
    extra_fields: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if actual_birth_date > _utc_today():
        raise ValueError("Date of birth cannot be in the future.")

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

    with get_connection() as conn:
        set_parts = []
        values: list[Any] = []
        for key, value in fields.items():
            set_parts.append(f"{key} = %s")
            values.append(value)
        set_parts.append("updated_at = now()")
        values.extend([baby_profile_id, firebase_uid])

        row = conn.execute(
            f"""
            UPDATE baby_profiles b
            SET {", ".join(set_parts)}
            FROM baby_memberships m
            WHERE b.id = m.baby_profile_id
              AND b.id = %s
              AND m.firebase_uid = %s
              AND m.role = 'owner'
              AND m.removed_at IS NULL
              AND b.deleted_at IS NULL
            RETURNING b.id, b.name, b.gender, b.expected_birth_date,
                      b.actual_birth_date, b.lifecycle_status
            """,
            values,
        ).fetchone()
        if row is None:
            raise PermissionError("Owner access required for this baby profile.")

        if record_arrival_event:
            insert_activity_event(
                baby_profile_id,
                firebase_uid,
                "baby_arrived",
                f"{baby_name} has arrived!",
                {"actual_birth_date": actual_birth_date.isoformat()},
                conn=conn,
            )

    result = dict(row)
    result["role"] = "owner"
    result["relationship_label"] = None
    return result


def build_home_summary(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
) -> dict[str, Any]:
    baby = get_baby_membership(firebase_uid, baby_profile_id)
    if baby is None:
        raise PermissionError("Membership required for this baby profile.")

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
    recent = list_recent_for_baby(baby_profile_id, limit=5)
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
                "deep_link": "/baby/edit",
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

    return {
        "baby_profile_id": baby_profile_id,
        "lifecycle_status": lifecycle,
        "days_to_due": days_to_due,
        "family_insight": {
            "name_suggestion_count": suggestion_count,
            "vote_count": vote_count,
            "gender_totals": totals,
            "top_name": top_name,
            "top_birthdate_guess": top_birthdate,
        },
        "next_up_event": next_up,
        "getting_started": getting_started,
        "recent_activity": [
            {
                "id": item["id"],
                "event_type": item["event_type"],
                "summary": item["summary"],
                "created_at": item["created_at"].isoformat()
                if hasattr(item["created_at"], "isoformat")
                else str(item["created_at"]),
            }
            for item in recent
        ],
    }
