from unittest.mock import patch

from lanonna_api.domain.users_display import (
    FAMILY_MEMBER_LABEL,
    UNKNOWN_ACTOR_LABEL,
    actor_display_name,
    author_display_name_from_row,
    member_display_name_from_row,
    rsvp_display_name_from_row,
    uploader_display_name_from_row,
)


def test_author_display_name_from_row_uses_sql_alias():
    assert author_display_name_from_row({"author_display_name": "Sarah QA"}) == "Sarah QA"


def test_author_display_name_ignores_email_on_row():
    row = {
        "author_display_name": None,
        "author_email": "sarah.qa@example.com",
    }
    assert author_display_name_from_row(row) == FAMILY_MEMBER_LABEL
    assert "@" not in author_display_name_from_row(row)


def test_uploader_and_rsvp_helpers_use_correct_fields():
    assert uploader_display_name_from_row({"uploader_display_name": " Alex "}) == "Alex"
    assert rsvp_display_name_from_row({"display_name": "Jordan"}) == "Jordan"
    assert rsvp_display_name_from_row({"display_name": "  "}) == FAMILY_MEMBER_LABEL


def test_member_display_name_trims_whitespace():
    assert member_display_name_from_row({"custom": "  Pat  "}, "custom") == "Pat"


def test_actor_display_name_never_uses_email():
    with patch(
        "lanonna_api.domain.users_display.get_app_user",
        return_value={"display_name": None, "email": "hidden@example.com"},
    ):
        assert actor_display_name("uid") == UNKNOWN_ACTOR_LABEL
        assert "@" not in actor_display_name("uid")
