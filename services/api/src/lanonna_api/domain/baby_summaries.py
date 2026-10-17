from __future__ import annotations

import uuid
from typing import Any

from lanonna_api.domain.avatar_urls import signed_avatar_url
from lanonna_api.domain.fun_closed import fun_closed_flags
from lanonna_api.domain.member_lifecycle import can_leave_baby
from lanonna_api.schemas.babies import BabySummary


def baby_summary_from_row(row: dict[str, Any]) -> BabySummary:
    closed = fun_closed_flags(row)
    return BabySummary(
        id=row["id"],
        name=row["name"],
        gender=row.get("gender"),
        expected_birth_date=row.get("expected_birth_date"),
        actual_birth_date=row.get("actual_birth_date"),
        lifecycle_status=row.get("lifecycle_status") or "expecting",
        role=row["role"],
        relationship_label=row.get("relationship_label"),
        avatar_url=signed_avatar_url(row.get("avatar_url")),
        can_leave=can_leave_baby(row["role"], row["active_owner_count"]),
        names_closed=closed["names_closed"],
        predictions_closed=closed["predictions_closed"],
    )
