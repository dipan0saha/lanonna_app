from datetime import datetime, timezone
from uuid import uuid4

from lanonna_api.pagination import (
    cursor_page_from_extra_row,
    decode_created_at_id_cursor,
    encode_created_at_id_cursor,
    offset_page,
    offset_page_from_extra_row,
)


def test_offset_page_from_extra_row_trims_probe_row():
    page = offset_page_from_extra_row([1, 2, 3], offset=10, limit=2)
    assert page == {
        "items": [1, 2],
        "offset": 10,
        "limit": 2,
        "has_more": True,
    }


def test_offset_page_from_extra_row_no_more():
    page = offset_page_from_extra_row([1], offset=0, limit=5)
    assert page["has_more"] is False
    assert page["items"] == [1]


def test_offset_page_explicit():
    payload = offset_page(["a"], offset=0, limit=1, has_more=False)
    assert payload["items"] == ["a"]


def test_cursor_page_from_extra_row_sets_next_cursor():
    now = datetime.now(timezone.utc)
    row_id = uuid4()
    row = {"created_at": now, "id": row_id}
    page = cursor_page_from_extra_row(
        [row, row],
        limit=1,
        cursor_for_row=lambda r: encode_created_at_id_cursor(r["created_at"], r["id"]),
    )
    assert page["has_more"] is True
    assert page["next_cursor"] == encode_created_at_id_cursor(now, row_id)
    decoded_at, decoded_id = decode_created_at_id_cursor(page["next_cursor"])
    assert decoded_id == row_id
    assert decoded_at == now
