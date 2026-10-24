import uuid
from contextlib import contextmanager
from unittest.mock import MagicMock, patch

from lanonna_worker.db import mark_photo_ready


def test_mark_photo_ready_inserts_photo_shared_activity():
    photo_id = uuid.uuid4()
    baby_id = uuid.uuid4()
    display_path = f"display/{photo_id}.webp"
    inserts: list[tuple] = []

    conn = MagicMock()

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        result = MagicMock()
        if "FROM photos" in sql_text and "display_object_generation" in sql_text:
            result.fetchone.return_value = None
        elif "SELECT baby_profile_id FROM photos" in sql_text:
            result.fetchone.return_value = {"baby_profile_id": baby_id}
        elif "FOR KEY SHARE" in sql_text:
            result.fetchone.return_value = {"?column?": 1}
        elif "UPDATE photos" in sql_text:
            result.fetchone.return_value = {
                "id": photo_id,
                "baby_profile_id": baby_id,
                "uploader_firebase_uid": "uploader-1",
                "caption": "Hello",
                "purpose": "gallery",
            }
        elif "FROM app_users" in sql_text:
            assert "email" not in sql_text
            result.fetchone.return_value = {"name": "Alex"}
        elif "INSERT INTO activity_events" in sql_text:
            inserts.append((sql_text, params))
            result.fetchone.return_value = None
        else:
            result.fetchone.return_value = None
        return result

    conn.execute.side_effect = execute

    @contextmanager
    def fake_connection():
        yield conn

    with patch("lanonna_worker.db.get_connection", fake_connection):
        row = mark_photo_ready(
            display_path=display_path,
            thumb_path=f"thumbnails/{photo_id}.jpg",
            object_generation=42,
            byte_length=1000,
        )

    assert row is not None
    assert row["id"] == photo_id
    assert len(inserts) == 1
    sql_text, params = inserts[0]
    assert params[3] == "photo_shared"
    assert params[4] == 'Alex shared "Hello"'
    assert params[5].obj == {"caption": "Hello"}
    assert params[6].obj == {"photo_id": str(photo_id)}


def test_mark_photo_ready_idempotent_generation():
    photo_id = uuid.uuid4()
    display_path = f"display/{photo_id}.webp"
    conn = MagicMock()
    result = MagicMock()
    result.fetchone.return_value = {"id": photo_id}
    conn.execute.return_value = result

    @contextmanager
    def fake_connection():
        yield conn

    with patch("lanonna_worker.db.get_connection", fake_connection):
        row = mark_photo_ready(
            display_path=display_path,
            thumb_path=f"thumbnails/{photo_id}.jpg",
            object_generation=99,
            byte_length=500,
        )

    assert row is None
    assert conn.execute.call_count == 1


def test_mark_photo_ready_skips_activity_for_event_cover():
    photo_id = uuid.uuid4()
    baby_id = uuid.uuid4()
    display_path = f"display/{photo_id}.webp"
    inserts: list[tuple] = []

    conn = MagicMock()

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        result = MagicMock()
        if "FROM photos" in sql_text and "display_object_generation" in sql_text:
            result.fetchone.return_value = None
        elif "SELECT baby_profile_id FROM photos" in sql_text:
            result.fetchone.return_value = {"baby_profile_id": baby_id}
        elif "FOR KEY SHARE" in sql_text:
            result.fetchone.return_value = {"?column?": 1}
        elif "UPDATE photos" in sql_text:
            result.fetchone.return_value = {
                "id": photo_id,
                "baby_profile_id": baby_id,
                "uploader_firebase_uid": "uploader-1",
                "caption": None,
                "purpose": "event_cover",
            }
        elif "INSERT INTO activity_events" in sql_text:
            inserts.append((sql_text, params))
            result.fetchone.return_value = None
        else:
            result.fetchone.return_value = None
        return result

    conn.execute.side_effect = execute

    @contextmanager
    def fake_connection():
        yield conn

    with patch("lanonna_worker.db.get_connection", fake_connection):
        row = mark_photo_ready(
            display_path=display_path,
            thumb_path=f"thumbnails/{photo_id}.jpg",
            object_generation=42,
            byte_length=1000,
        )

    assert row is not None
    assert inserts == []


def test_mark_photo_ready_locks_baby_before_photo_and_skips_when_baby_gone():
    """#442: baby FOR KEY SHARE precedes the photo UPDATE; a deleted baby is a no-op."""
    photo_id = uuid.uuid4()
    baby_id = uuid.uuid4()
    display_path = f"display/{photo_id}.webp"
    statements: list[str] = []

    conn = MagicMock()

    def execute(sql, params=None):
        sql_text = " ".join(sql.split())
        statements.append(sql_text)
        result = MagicMock()
        if "SELECT baby_profile_id FROM photos" in sql_text:
            result.fetchone.return_value = {"baby_profile_id": baby_id}
        else:
            # Baby row already hard-deleted: FOR KEY SHARE finds nothing.
            result.fetchone.return_value = None
        return result

    conn.execute.side_effect = execute

    @contextmanager
    def fake_connection():
        yield conn

    with patch("lanonna_worker.db.get_connection", fake_connection):
        row = mark_photo_ready(
            display_path=display_path,
            thumb_path=f"thumbnails/{photo_id}.jpg",
            object_generation=None,
            byte_length=1000,
        )

    assert row is None
    assert any("FOR KEY SHARE" in s for s in statements)
    assert not any("UPDATE photos" in s for s in statements)
    assert not any("INSERT INTO activity_events" in s for s in statements)
