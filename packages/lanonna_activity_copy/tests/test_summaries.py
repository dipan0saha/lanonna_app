from lanonna_activity_copy import (
    photo_comment_summary,
    photo_shared_summary,
    photo_squish_summary,
)


def test_photo_shared_summary_with_caption():
    assert photo_shared_summary("Sarah", "Bump update") == 'Sarah added "Bump update"'


def test_photo_shared_summary_without_caption():
    assert photo_shared_summary("Sarah", None) == "Sarah shared a photo"


def test_photo_squish_summary():
    assert "squished" in photo_squish_summary("Sue", "Nursery")


def test_photo_comment_summary():
    assert "commented on" in photo_comment_summary("Carol", "Ultrasound")


def test_truncate_long_caption():
    long_caption = "x" * 80
    summary = photo_shared_summary("Alex", long_caption)
    assert "Alex added" in summary
    assert "…" in summary
