import pytest

from lanonna_activity_copy import (
    NOTIFICATION_TYPE_BY_KIND,
    NotificationKind,
    activity_summary,
    caption_params,
    notification_kind_from_payload,
    push_copy,
)


def test_caption_params_only_when_present():
    assert caption_params("  Bump update ") == {"caption": "Bump update"}
    assert caption_params("   ") == {}
    assert caption_params(None) == {}


def test_activity_summary_is_diagnostic_english():
    assert activity_summary("photo_shared", {}, actor="Sarah") == "Sarah shared a photo"
    assert (
        activity_summary("photo_squish", {"caption": "Nursery"}, actor="Sue")
        == 'Sue squished "Nursery"'
    )
    assert activity_summary("registry_claimed", {"item_name": "Swaddles"}, actor="Ann") == (
        'Someone is buying "Swaddles"'
    )
    assert activity_summary("member_removed", {}, actor="Mom", target="Ann") == (
        "Mom removed Ann from the family"
    )


def test_every_kind_has_a_category_and_push_copy():
    assert set(NOTIFICATION_TYPE_BY_KIND) == set(NotificationKind)
    for kind in NotificationKind:
        title, body = push_copy(kind, {}, actor="Sue")
        assert title and body


@pytest.mark.parametrize(
    ("status", "expected"),
    [
        ("going", 'Sue is going to "Shower"'),
        ("maybe", 'Sue might go to "Shower"'),
        ("cant_go", 'Sue can\'t make it to "Shower"'),
        ("bogus", 'Sue replied to "Shower"'),
    ],
)
def test_rsvp_push_copy_never_shows_raw_status(status, expected):
    _, body = push_copy(
        NotificationKind.EVENT_RSVP,
        {"event_title": "Shower", "rsvp_status": status},
        actor="Sue",
    )
    assert body == expected


def test_push_copy_fallbacks():
    assert push_copy(NotificationKind.INVITE_ACCEPTED, {"baby_name": ""}, actor=None) == (
        "Invite accepted",
        "Someone joined your baby",
    )
    assert push_copy(NotificationKind.WEEKLY_DIGEST, {"unread_count": 1}, actor=None)[1] == (
        "You have 1 unread update from La Nonna"
    )


def test_kind_from_payload():
    assert notification_kind_from_payload("photo_squished") is NotificationKind.PHOTO_SQUISHED
    assert notification_kind_from_payload(None) is None
    assert notification_kind_from_payload("nope") is None
