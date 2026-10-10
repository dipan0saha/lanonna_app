from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.media_urls import signed_thumb_url
from lanonna_api.domain.membership_access import require_active_membership
from lanonna_api.repositories.search import (
    search_events,
    search_name_suggestions,
    search_photos,
    search_registry_items,
)
def search_baby_content(
    firebase_uid: str,
    baby_profile_id: uuid.UUID,
    query: str,
    limit: int = 20,
) -> dict[str, Any]:
    require_active_membership(firebase_uid, baby_profile_id)

    q = query.strip()
    if not q:
        return {
            "query": "",
            "photos": [],
            "events": [],
            "registry_items": [],
            "name_suggestions": [],
        }

    pattern = f"%{q}%"
    per_type = max(1, min(limit, 20))

    photos = [
        {
            "id": str(p["id"]),
            "caption": p.get("caption"),
            "thumb_url": signed_thumb_url(p.get("thumb_path")),
        }
        for p in search_photos(baby_profile_id, pattern, per_type)
    ]
    events = [
        {
            "id": str(e["id"]),
            "title": e["title"],
            "starts_at": e["starts_at"].isoformat()
            if hasattr(e["starts_at"], "isoformat")
            else str(e["starts_at"]),
        }
        for e in search_events(baby_profile_id, pattern, per_type)
    ]
    registry_items = [
        {"id": str(r["id"]), "name": r["name"]}
        for r in search_registry_items(baby_profile_id, pattern, per_type)
    ]
    name_suggestions = [
        {"id": str(n["id"]), "name": n["name"]}
        for n in search_name_suggestions(baby_profile_id, pattern, per_type)
    ]

    return {
        "query": q,
        "photos": photos,
        "events": events,
        "registry_items": registry_items,
        "name_suggestions": name_suggestions,
    }
