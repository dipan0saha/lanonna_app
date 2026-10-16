from lanonna_api.pagination import offset_page, offset_page_from_extra_row


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
