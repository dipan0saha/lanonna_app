"""Shared offset-pagination envelope for list endpoints."""

from __future__ import annotations

from typing import Any, Sequence, TypeVar

T = TypeVar("T")


def offset_page(
    items: Sequence[T],
    *,
    offset: int,
    limit: int,
    has_more: bool,
) -> dict[str, Any]:
    return {
        "items": list(items),
        "offset": offset,
        "limit": limit,
        "has_more": has_more,
    }


def offset_page_from_extra_row(
    rows: Sequence[T],
    *,
    offset: int,
    limit: int,
) -> dict[str, Any]:
    """``rows`` was fetched with ``limit + 1`` to detect a next page."""
    has_more = len(rows) > limit
    return offset_page(rows[:limit], offset=offset, limit=limit, has_more=has_more)
