from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from lanonna_api.domain.avatar_urls import signed_baby_avatar_urls_from_rows
from lanonna_api.domain.fun_closed import fun_closed_flags
from lanonna_api.domain.member_lifecycle import can_leave_baby
from lanonna_api.schemas.babies import BabySummary


def baby_summaries_from_rows(rows: Sequence[dict[str, Any]]) -> list[BabySummary]:
    """Summaries for baby rows; every avatar URL is signed in one batch."""
    avatars = signed_baby_avatar_urls_from_rows(rows)
    summaries: list[BabySummary] = []
    for row, avatar_url in zip(rows, avatars):
        closed = fun_closed_flags(row)
        summaries.append(
            BabySummary(
                id=row["id"],
                name=row["name"],
                gender=row.get("gender"),
                expected_birth_date=row.get("expected_birth_date"),
                actual_birth_date=row.get("actual_birth_date"),
                lifecycle_status=row.get("lifecycle_status") or "expecting",
                role=row["role"],
                relationship_label=row.get("relationship_label"),
                avatar_url=avatar_url,
                can_leave=can_leave_baby(row["role"], row["active_owner_count"]),
                names_closed=closed["names_closed"],
                predictions_closed=closed["predictions_closed"],
            )
        )
    return summaries


def baby_summary_from_row(row: dict[str, Any]) -> BabySummary:
    return baby_summaries_from_rows([row])[0]
