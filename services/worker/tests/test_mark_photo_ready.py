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
        elif "UPDATE photos" in sql_text:
            result.fetchone.return_value = {
                "id": photo_id,
                "baby_profile_id": baby_id,
                "uploader_firebase_uid": "uploader-1",
                "caption": "Hello",
            }
        elif "FROM app_users" in sql_text:
            result.fetchone.return_value = {"actor_name": "Alex"}
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
    assert "photo_shared" in sql_text
    payload = params[4]
    photo_id_value = payload.obj if hasattr(payload, "obj") else payload
    assert photo_id_value["photo_id"] == str(photo_id)
    assert "Alex" in params[3]


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
