"""Shared offset- and cursor-pagination envelopes for list endpoints."""

from __future__ import annotations

import base64
import json
import uuid
from datetime import datetime
from typing import Any, Callable, Sequence, TypeVar

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


def encode_created_at_id_cursor(created_at: datetime, row_id: uuid.UUID) -> str:
    payload = {"created_at": created_at.isoformat(), "id": str(row_id)}
    raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii")


def decode_created_at_id_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        raw = base64.urlsafe_b64decode(cursor.encode("ascii"))
        payload = json.loads(raw.decode("utf-8"))
        created_at = datetime.fromisoformat(payload["created_at"])
        row_id = uuid.UUID(payload["id"])
    except (ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise ValueError("invalid cursor") from exc
    return created_at, row_id


def cursor_page(
    items: Sequence[T],
    *,
    limit: int,
    has_more: bool,
    next_cursor: str | None,
) -> dict[str, Any]:
    return {
        "items": list(items),
        "limit": limit,
        "has_more": has_more,
        "next_cursor": next_cursor,
    }


def cursor_page_from_extra_row(
    rows: Sequence[Any],
    *,
    limit: int,
    cursor_for_row: Callable[[Any], str],
) -> dict[str, Any]:
    """``rows`` was fetched with ``limit + 1`` to detect a next page."""
    has_more = len(rows) > limit
    items = list(rows[:limit])
    next_cursor = cursor_for_row(items[-1]) if has_more and items else None
    return cursor_page(items, limit=limit, has_more=has_more, next_cursor=next_cursor)
