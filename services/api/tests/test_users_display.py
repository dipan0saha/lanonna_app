from lanonna_api.domain.users_display import (
    author_display_name_from_row,
    member_display_name_from_row,
    rsvp_display_name_from_row,
    uploader_display_name_from_row,
)


def test_author_display_name_from_row_uses_sql_alias():
    assert author_display_name_from_row({"author_display_name": "Sarah QA"}) == "Sarah QA"


def test_missing_name_is_null_never_email_or_english():
    row = {
        "author_display_name": None,
        "author_email": "sarah.qa@example.com",
    }
    # The app shows its localized fallback ("Family member") for null.
    assert author_display_name_from_row(row) is None


def test_uploader_and_rsvp_helpers_use_correct_fields():
    assert uploader_display_name_from_row({"uploader_display_name": " Alex "}) == "Alex"
    assert rsvp_display_name_from_row({"display_name": "Jordan"}) == "Jordan"
    assert rsvp_display_name_from_row({"display_name": "  "}) is None


def test_member_display_name_trims_whitespace():
    assert member_display_name_from_row({"custom": "  Pat  "}, "custom") == "Pat"
