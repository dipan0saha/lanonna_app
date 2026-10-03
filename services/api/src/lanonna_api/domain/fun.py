from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from lanonna_api.domain.gallery import require_membership
from lanonna_api.domain.users_display import author_display_name_from_row
from lanonna_api.repositories.activity_events import insert_activity_event
from lanonna_api.repositories.babies import get_baby_membership
from lanonna_api.repositories.fun import (
    add_like,
    birthdate_vote_histogram,
    caller_liked_suggestion_ids,
    count_suggestions_by_author_gender,
    delete_name_suggestion,
    gender_vote_totals,
    get_caller_votes,
    get_name_suggestion,
    insert_name_suggestion,
    list_gender_voters,
    list_name_suggestions,
    remove_like,
    remove_likes_for_user_gender,
    set_vote_anonymous,
    upsert_birthdate_vote,
    upsert_gender_vote,
    user_has_like,
)
from lanonna_api.repositories.users import upsert_app_user


def list_names(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    liked = caller_liked_suggestion_ids(baby_profile_id, firebase_uid)
    suggestions = []
    for row in list_name_suggestions(baby_profile_id):
        sid = row["id"]
        suggestions.append(
            {
                "id": str(sid),
                "suggested_name": row["suggested_name"],
                "gender": row["gender"],
                "like_count": row["like_count"],
                "author_display_name": author_display_name_from_row(row),
                "is_mine": row["suggested_by_firebase_uid"] == firebase_uid,
                "viewer_has_liked": user_has_like(sid, firebase_uid),
            }
        )
    return {
        "suggestions": suggestions,
        "viewer_liked_by_gender": {
            "male": str(liked["male"]) if liked.get("male") else None,
            "female": str(liked["female"]) if liked.get("female") else None,
        },
    }


def suggest_name(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    suggested_name: str,
    gender: str,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    if gender not in ("male", "female"):
        raise ValueError("Gender must be male or female.")
    if not suggested_name.strip():
        raise ValueError("Name is required.")
    membership = get_baby_membership(firebase_uid, baby_profile_id)
    if membership and membership["role"] != "owner":
        if count_suggestions_by_author_gender(baby_profile_id, firebase_uid, gender) >= 1:
            raise PermissionError("You already suggested a name for this gender.")
    upsert_app_user(firebase_uid, None)
    row = insert_name_suggestion(
        baby_profile_id, firebase_uid, suggested_name, gender
    )
    insert_activity_event(
        baby_profile_id,
        firebase_uid,
        "name_suggested",
        f'Suggested the name "{row["suggested_name"]}"',
        {"name_suggestion_id": str(row["id"])},
    )
    return {
        "id": str(row["id"]),
        "suggested_name": row["suggested_name"],
        "gender": row["gender"],
    }


def remove_suggestion(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    suggestion_id: uuid.UUID,
) -> None:
    require_membership(firebase_uid, baby_profile_id)
    membership = get_baby_membership(firebase_uid, baby_profile_id)
    row = get_name_suggestion(baby_profile_id, suggestion_id)
    if row is None:
        raise LookupError("Suggestion not found.")
    is_owner = membership is not None and membership["role"] == "owner"
    is_author = row["suggested_by_firebase_uid"] == firebase_uid
    if not is_owner and not is_author:
        raise PermissionError("Cannot delete this suggestion.")
    if not delete_name_suggestion(baby_profile_id, suggestion_id):
        raise LookupError("Suggestion not found.")


def toggle_like(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    suggestion_id: uuid.UUID,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    row = get_name_suggestion(baby_profile_id, suggestion_id)
    if row is None:
        raise LookupError("Suggestion not found.")
    gender = row["gender"]
    if user_has_like(suggestion_id, firebase_uid):
        remove_like(suggestion_id, firebase_uid)
        return {"liked": False}
    remove_likes_for_user_gender(baby_profile_id, firebase_uid, gender)
    add_like(suggestion_id, firebase_uid)
    return {"liked": True}


def get_predictions(firebase_uid: str, baby_profile_id: uuid.UUID) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    totals = gender_vote_totals(baby_profile_id)
    caller = get_caller_votes(baby_profile_id, firebase_uid)
    voters = []
    for v in list_gender_voters(baby_profile_id):
        name = "Anonymous"
        if not v.get("is_anonymous"):
            name = v.get("display_name") or (
                v.get("email", "").split("@")[0] if v.get("email") else "Family member"
            )
        voters.append(
            {
                "gender": v["gender_value"],
                "display_name": name,
                "is_anonymous": v.get("is_anonymous", True),
            }
        )
    hist = birthdate_vote_histogram(baby_profile_id)
    return {
        "gender_totals": totals,
        "viewer_gender_vote": caller.get("gender"),
        "viewer_birthdate_vote": caller.get("birthdate").isoformat()
        if caller.get("birthdate") and hasattr(caller.get("birthdate"), "isoformat")
        else (
            str(caller.get("birthdate")) if caller.get("birthdate") else None
        ),
        "is_anonymous": caller.get("is_anonymous", True),
        "gender_voters": voters,
        "birthdate_histogram": [
            {
                "date": row["predicted_birth_date"].isoformat()
                if hasattr(row["predicted_birth_date"], "isoformat")
                else str(row["predicted_birth_date"]),
                "count": row["count"],
            }
            for row in hist
        ],
    }


def set_gender_vote(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    gender_value: str,
    is_anonymous: bool = True,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    if gender_value not in ("male", "female"):
        raise ValueError("Invalid gender vote.")
    upsert_app_user(firebase_uid, None)
    upsert_gender_vote(baby_profile_id, firebase_uid, gender_value, is_anonymous)
    insert_activity_event(
        baby_profile_id,
        firebase_uid,
        "gender_vote_cast",
        f'Guessed "{gender_value}"',
        {},
    )
    return {"gender": gender_value}


def set_birthdate_vote(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    predicted_birth_date: date,
    is_anonymous: bool = True,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    upsert_app_user(firebase_uid, None)
    upsert_birthdate_vote(
        baby_profile_id, firebase_uid, predicted_birth_date, is_anonymous
    )
    return {"date": predicted_birth_date.isoformat()}


def patch_anonymous(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    is_anonymous: bool,
) -> dict[str, Any]:
    require_membership(firebase_uid, baby_profile_id)
    set_vote_anonymous(baby_profile_id, firebase_uid, is_anonymous)
    return {"is_anonymous": is_anonymous}
