"""Shape collected rows into export_version 2. No SQL."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from typing import Any, Callable

from lanonna_worker.export.collect import ACTIVITY_EXPORT_MAX_ROWS
from lanonna_worker.export.media import EXPORT_MEDIA_URL_TTL_SECONDS
from lanonna_worker.export.people import (
    ANONYMOUS_LABEL,
    FAMILY_MEMBER_LABEL,
    UNKNOWN_ACTOR_LABEL,
    assert_export_privacy,
    export_display_name,
    person_id_for,
    scrub_payload,
)

EXPORT_VERSION = 2

SignRead = Callable[[str, str], str]

_MEDIA_NOTE = (
    "download_url values are V4 signed GET URLs minted when this export was "
    "built. They expire at download_url_expires_at (at most 7 days, the V4 "
    "maximum). Download export.json with the short-lived link from the app, "
    "then fetch each file before that time. Run export again to refresh them. "
    "Purchases are included with the purchaser's display name, matching the "
    "registry screen (there is no hidden-purchaser rule)."
)


def _iso(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return str(value)
    return str(value)


def _media_ref(
    *,
    bucket: str,
    object_path: str | None,
    sign_read: SignRead,
    expires_at: datetime,
) -> dict[str, str] | None:
    if not object_path:
        return None
    path = str(object_path).strip()
    if not path:
        return None
    if path.startswith("http://") or path.startswith("https://"):
        return {"download_url": path}
    return {
        "bucket": bucket,
        "object_path": path,
        "download_url": sign_read(bucket, path),
        "download_url_expires_at": _iso(expires_at) or "",
    }


class _People:
    def __init__(self, baby_id: uuid.UUID) -> None:
        self.baby_id = baby_id
        self.by_uid: dict[str, dict[str, Any]] = {}
        self.firebase_uids: set[str] = set()
        self.member_emails: set[str] = set()
        self.email_to_uid: dict[str, str] = {}

    def add(
        self,
        firebase_uid: str | None,
        display_name: Any,
        *,
        role: str | None = None,
        relationship: str | None = None,
        joined_at: Any = None,
        removed_at: Any = None,
        joined_via: str | None = None,
        email: str | None = None,
        unknown_actor: bool = False,
    ) -> str | None:
        if not firebase_uid:
            return None
        uid = str(firebase_uid)
        self.firebase_uids.add(uid)
        if email:
            self.member_emails.add(str(email))
            self.email_to_uid[str(email).strip().lower()] = uid
        pid = person_id_for(self.baby_id, uid)
        current = self.by_uid.get(uid)
        if current is None:
            self.by_uid[uid] = {
                "id": pid,
                "display_name": export_display_name(
                    display_name, unknown_actor=unknown_actor
                ),
                "relationship": relationship,
                "role": role,
                "joined_at": _iso(joined_at),
                "removed_at": _iso(removed_at),
                "joined_via": joined_via,
            }
            return pid
        if display_name and current["display_name"] in (FAMILY_MEMBER_LABEL, UNKNOWN_ACTOR_LABEL):
            current["display_name"] = export_display_name(display_name)
        if role is not None:
            current["role"] = role
        if relationship is not None:
            current["relationship"] = relationship
        if joined_at is not None and current["joined_at"] is None:
            current["joined_at"] = _iso(joined_at)
        if removed_at is not None:
            current["removed_at"] = _iso(removed_at)
        if joined_via is not None:
            current["joined_via"] = joined_via
        return pid

    def pid(self, firebase_uid: str | None) -> str | None:
        if not firebase_uid:
            return None
        uid = str(firebase_uid)
        self.firebase_uids.add(uid)
        return person_id_for(self.baby_id, uid)

    def as_list(self) -> list[dict[str, Any]]:
        return sorted(self.by_uid.values(), key=lambda row: (row["display_name"], row["id"]))


def _comment(row: dict[str, Any], people: _People) -> dict[str, Any]:
    pid = people.add(
        row.get("author_firebase_uid"),
        row.get("author_display_name"),
    )
    return {
        "id": _iso(row["id"]),
        "person_id": pid,
        "body": row.get("body"),
        "created_at": _iso(row.get("created_at")),
        "updated_at": _iso(row.get("updated_at")),
    }


def _squish(row: dict[str, Any], people: _People) -> dict[str, Any]:
    pid = people.add(row.get("firebase_uid"), row.get("display_name"))
    return {"person_id": pid, "created_at": _iso(row.get("created_at"))}


def build_export_document(
    collected: dict[str, Any],
    *,
    baby_id: uuid.UUID,
    sign_read: SignRead,
    display_bucket: str,
    thumbnails_bucket: str,
    exported_at: datetime | None = None,
) -> dict[str, Any]:
    now = exported_at or datetime.now(timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    expires_at = datetime.fromtimestamp(
        now.timestamp() + EXPORT_MEDIA_URL_TTL_SECONDS, tz=timezone.utc
    )
    people = _People(baby_id)
    baby = collected["baby"]
    secrets: set[str] = set()

    for member in collected["memberships"]:
        people.add(
            member["firebase_uid"],
            member.get("display_name"),
            role=member.get("role"),
            relationship=member.get("relationship_label"),
            joined_at=member.get("created_at"),
            removed_at=member.get("removed_at"),
            joined_via=member.get("joined_via"),
            email=member.get("email"),
        )
    people.add(baby.get("created_by_firebase_uid"), None, unknown_actor=True)

    def media(bucket: str, path: str | None) -> dict[str, str] | None:
        return _media_ref(
            bucket=bucket,
            object_path=path,
            sign_read=sign_read,
            expires_at=expires_at,
        )

    comments_by_photo: dict[str, list[dict[str, Any]]] = {}
    for row in collected["photo_comments"]:
        comments_by_photo.setdefault(str(row["photo_id"]), []).append(_comment(row, people))
    squishes_by_photo: dict[str, list[dict[str, Any]]] = {}
    for row in collected["photo_squishes"]:
        squishes_by_photo.setdefault(str(row["photo_id"]), []).append(_squish(row, people))
    tags_by_photo: dict[str, list[dict[str, str]]] = {}
    for row in collected["photo_tags"]:
        tags_by_photo.setdefault(str(row["photo_id"]), []).append(
            {
                "baby_profile_id": str(row["tagged_baby_profile_id"]),
                "name": row["name"],
            }
        )

    photos = []
    for row in collected["photos"]:
        pid = people.add(row.get("uploader_firebase_uid"), None, unknown_actor=True)
        photo_key = str(row["id"])
        photos.append(
            {
                "id": photo_key,
                "caption": row.get("caption"),
                "status": row.get("status"),
                "content_type": row.get("content_type"),
                "byte_length": row.get("byte_length"),
                "created_by": pid,
                "created_at": _iso(row.get("created_at")),
                "updated_at": _iso(row.get("updated_at")),
                "display": media(display_bucket, row.get("display_path")),
                "thumbnail": media(thumbnails_bucket, row.get("thumb_path")),
                "tags": tags_by_photo.get(photo_key, []),
                "squishes": squishes_by_photo.get(photo_key, []),
                "comments": comments_by_photo.get(photo_key, []),
            }
        )

    rsvps_by_event: dict[str, list[dict[str, Any]]] = {}
    for row in collected["event_rsvps"]:
        pid = people.add(row.get("firebase_uid"), row.get("display_name"))
        rsvps_by_event.setdefault(str(row["event_id"]), []).append(
            {
                "person_id": pid,
                "status": row.get("status"),
                "created_at": _iso(row.get("created_at")),
                "updated_at": _iso(row.get("updated_at")),
            }
        )
    comments_by_event: dict[str, list[dict[str, Any]]] = {}
    for row in collected["event_comments"]:
        comments_by_event.setdefault(str(row["event_id"]), []).append(_comment(row, people))

    events = []
    for row in collected["events"]:
        event_key = str(row["id"])
        events.append(
            {
                "id": event_key,
                "title": row.get("title"),
                "starts_at": _iso(row.get("starts_at")),
                "ends_at": _iso(row.get("ends_at")),
                "description": row.get("description"),
                "location": row.get("location"),
                "video_call_url": row.get("video_call_url"),
                "cover_photo_id": _iso(row.get("cover_photo_id")),
                "catalog_suggestion_id": row.get("catalog_suggestion_id"),
                "created_by": people.add(
                    row.get("created_by_firebase_uid"), None, unknown_actor=True
                ),
                "created_at": _iso(row.get("created_at")),
                "updated_at": _iso(row.get("updated_at")),
                "rsvps": rsvps_by_event.get(event_key, []),
                "comments": comments_by_event.get(event_key, []),
            }
        )

    purchase_by_item = {str(row["registry_item_id"]): row for row in collected["purchases"]}
    registry_items = []
    for row in collected["registry_items"]:
        purchase_row = purchase_by_item.get(str(row["id"]))
        purchase = None
        if purchase_row is not None:
            purchase = {
                "id": _iso(purchase_row["id"]),
                "person_id": people.add(
                    purchase_row.get("purchased_by_firebase_uid"),
                    purchase_row.get("purchaser_display_name"),
                ),
                "purchased_at": _iso(purchase_row.get("created_at")),
            }
        registry_items.append(
            {
                "id": str(row["id"]),
                "name": row.get("name"),
                "description": row.get("description"),
                "product_url": row.get("product_url"),
                "priority": row.get("priority"),
                "catalog_suggestion_id": row.get("catalog_suggestion_id"),
                "created_by": people.add(
                    row.get("created_by_firebase_uid"), None, unknown_actor=True
                ),
                "created_at": _iso(row.get("created_at")),
                "updated_at": _iso(row.get("updated_at")),
                "purchase": purchase,
            }
        )

    likes_by_name: dict[str, list[dict[str, Any]]] = {}
    for row in collected["name_likes"]:
        likes_by_name.setdefault(str(row["name_suggestion_id"]), []).append(
            {
                "person_id": people.add(row.get("firebase_uid"), row.get("display_name")),
                "created_at": _iso(row.get("created_at")),
            }
        )
    name_suggestions = []
    for row in collected["name_suggestions"]:
        name_suggestions.append(
            {
                "id": str(row["id"]),
                "suggested_name": row.get("suggested_name"),
                "gender": row.get("gender"),
                "suggested_by": people.add(
                    row.get("suggested_by_firebase_uid"),
                    row.get("suggester_display_name"),
                ),
                "created_at": _iso(row.get("created_at")),
                "loves": likes_by_name.get(str(row["id"]), []),
            }
        )

    gender_votes = []
    birthdate_votes = []
    for row in collected["votes"]:
        anonymous = bool(row.get("is_anonymous"))
        if anonymous:
            vote_person = None
            vote_name = ANONYMOUS_LABEL
            people.firebase_uids.add(str(row["firebase_uid"]))
        else:
            vote_person = people.add(row.get("firebase_uid"), row.get("display_name"))
            vote_name = export_display_name(row.get("display_name"))
        shaped = {
            "person_id": vote_person,
            "display_name": vote_name,
            "is_anonymous": anonymous,
            "created_at": _iso(row.get("created_at")),
            "updated_at": _iso(row.get("updated_at")),
        }
        if row.get("vote_type") == "gender":
            shaped["gender"] = row.get("gender_value")
            gender_votes.append(shaped)
        else:
            shaped["predicted_birth_date"] = _iso(row.get("predicted_birth_date"))
            birthdate_votes.append(shaped)

    announcement = None
    raw_announcement = collected.get("announcement")
    if raw_announcement is not None:
        announcement = {
            "id": str(raw_announcement["id"]),
            "photo_id": _iso(raw_announcement.get("photo_id")),
            "first_name": raw_announcement.get("first_name"),
            "last_name": raw_announcement.get("last_name"),
            "gender": raw_announcement.get("gender"),
            "birth_date": _iso(raw_announcement.get("birth_date")),
            "birth_time": raw_announcement.get("birth_time"),
            "weight_text": raw_announcement.get("weight_text"),
            "length_text": raw_announcement.get("length_text"),
            "created_by": people.add(
                raw_announcement.get("created_by_firebase_uid"),
                raw_announcement.get("author_display_name"),
            ),
            "created_at": _iso(raw_announcement.get("created_at")),
            "updated_at": _iso(raw_announcement.get("updated_at")),
            "squishes": [_squish(row, people) for row in collected["announcement_squishes"]],
            "comments": [_comment(row, people) for row in collected["announcement_comments"]],
        }

    invitations = []
    for row in collected["invitations"]:
        for secret_key in ("token_hash", "email_invite_token"):
            secret = row.get(secret_key)
            if secret:
                secrets.add(str(secret))
        invitee_email = (row.get("invitee_email") or "").strip()
        member_uid = people.email_to_uid.get(invitee_email.lower())
        shaped_invite: dict[str, Any] = {
            "id": str(row["id"]),
            "role": row.get("role"),
            "relationship": row.get("relationship_label"),
            "status": row.get("status"),
            "expires_at": _iso(row.get("expires_at")),
            "created_at": _iso(row.get("created_at")),
            "inviter": people.add(
                row.get("inviter_firebase_uid"),
                row.get("inviter_display_name"),
            ),
        }
        # Pending invites are addressed by the email the owner typed.
        # Once that address belongs to a member, keep the person id only.
        if member_uid is None and row.get("status") == "pending" and invitee_email:
            shaped_invite["invitee_email"] = invitee_email
        elif member_uid is not None:
            shaped_invite["person_id"] = person_id_for(baby_id, member_uid)
        invitations.append(shaped_invite)

    prepared_activity: list[tuple[dict[str, Any], str | None]] = []
    for row in collected["activity"]:
        actor_uid = row.get("actor_firebase_uid")
        actor = None
        if actor_uid:
            actor = people.add(
                actor_uid,
                row.get("actor_display_name"),
                unknown_actor=row.get("actor_display_name") in (None, ""),
            )
        prepared_activity.append((row, actor))
    uid_to_person = {
        uid: person_id_for(baby_id, uid) for uid in people.firebase_uids
    }
    activity = []
    for row, actor in prepared_activity:
        activity.append(
            {
                "id": str(row["id"]),
                "actor": actor,
                "event_type": row.get("event_type"),
                "params": row.get("params") or {},
                "summary": row.get("summary"),
                "payload": scrub_payload(row.get("payload"), uid_to_person),
                "created_at": _iso(row.get("created_at")),
            }
        )

    activity_total = int(collected.get("activity_total") or 0)
    document = {
        "export_version": EXPORT_VERSION,
        "exported_at": _iso(now),
        "baby_profile_id": str(baby_id),
        "covered_tables": list(collected.get("covered_tables") or []),
        "people": people.as_list(),
        "baby_profile": {
            "id": str(baby["id"]),
            "name": baby.get("name"),
            "expected_birth_date": _iso(baby.get("expected_birth_date")),
            "actual_birth_date": _iso(baby.get("actual_birth_date")),
            "gender": baby.get("gender"),
            "lifecycle_status": baby.get("lifecycle_status"),
            "created_at": _iso(baby.get("created_at")),
            "updated_at": _iso(baby.get("updated_at")),
            "created_by": people.pid(baby.get("created_by_firebase_uid")),
            "avatar": media(display_bucket, baby.get("avatar_url")),
            "registry_shipping": {
                "line1": baby.get("registry_shipping_line1"),
                "line2": baby.get("registry_shipping_line2"),
                "city": baby.get("registry_shipping_city"),
                "region": baby.get("registry_shipping_region"),
                "postal_code": baby.get("registry_shipping_postal_code"),
                "country_code": (
                    str(baby["registry_shipping_country_code"]).strip()
                    if baby.get("registry_shipping_country_code")
                    else None
                ),
            },
        },
        "members": [
            person
            for person in people.as_list()
            if person.get("role") is not None
        ],
        "invitations": invitations,
        "photos": photos,
        "events": events,
        "registry_items": registry_items,
        "name_suggestions": name_suggestions,
        "predictions": {
            "gender_votes": gender_votes,
            "birthdate_votes": birthdate_votes,
        },
        "announcement": announcement,
        "activity_events": activity,
        "activity_truncated": activity_total > ACTIVITY_EXPORT_MAX_ROWS,
        "activity_total": activity_total,
        "media": {
            "url_ttl_seconds": EXPORT_MEDIA_URL_TTL_SECONDS,
            "note": _MEDIA_NOTE,
        },
    }
    # people.as_list() was snapshotted before later add() calls. Rebuild.
    document["people"] = people.as_list()
    document["members"] = [
        person for person in document["people"] if person.get("role") is not None
    ]
    assert_export_privacy(
        document,
        firebase_uids=people.firebase_uids,
        member_emails=people.member_emails,
        secrets=secrets,
    )
    return document
