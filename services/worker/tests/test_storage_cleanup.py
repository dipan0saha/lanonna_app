import uuid
from unittest.mock import MagicMock, patch

import pytest
from google.api_core.exceptions import NotFound

from lanonna_worker import gcs_delete
from lanonna_worker.gcs_delete import GcsDeleteError
from lanonna_worker.storage_cleanup import run_storage_cleanup, sweep_storage_cleanup_jobs


def _conn(job: dict | None, photo_rows: list[dict] | None = None):
    conn = MagicMock()

    def execute(sql, params=None):
        text = " ".join(sql.split())
        result = MagicMock()
        if "SET status = 'running'" in text:
            result.fetchone.return_value = job
        elif "FROM photos" in text:
            result.fetchall.return_value = photo_rows or []
        return result

    conn.execute.side_effect = execute
    return conn


def _job(kind: str, baby_id: uuid.UUID) -> dict:
    return {
        "kind": kind,
        "firebase_uid": "user-1",
        "baby_profile_ids": [baby_id],
        "detached_objects": [
            {"display_path": "display/detached.webp", "thumb_path": "thumbnails/d.jpg"}
        ],
        "export_object_paths": ["exports/b/j/export.json"],
    }


def _sql(conn) -> list[str]:
    return [" ".join(c.args[0].split()) for c in conn.execute.call_args_list]


@pytest.fixture
def gcs():
    with (
        patch("lanonna_worker.storage_cleanup.gcs_delete.delete_photo_paths", return_value=2) as photos,
        patch("lanonna_worker.storage_cleanup.gcs_delete.delete_display_paths", return_value=1) as exports,
        patch("lanonna_worker.storage_cleanup.gcs_delete.delete_prefix", return_value=0) as prefix,
    ):
        yield photos, exports, prefix


def test_account_job_deletes_detached_baby_photos_exports_and_avatars(gcs):
    photos, exports, prefix = gcs
    baby_id = uuid.uuid4()
    conn = _conn(
        _job("account_delete", baby_id),
        [{"display_path": "display/baby.webp", "thumb_path": None}],
    )
    with patch("lanonna_worker.storage_cleanup.get_connection") as ctx:
        ctx.return_value.__enter__.return_value = conn
        run_storage_cleanup(uuid.uuid4())

    assert [c.args for c in photos.call_args_list] == [
        ("display/detached.webp", "thumbnails/d.jpg"),
        ("display/baby.webp", None),
    ]
    exports.assert_called_once_with(["exports/b/j/export.json"])
    assert {c.args[1] for c in prefix.call_args_list} == {
        f"avatars/babies/{baby_id}/",
        f"exports/{baby_id}/",
        "avatars/users/user-1/",
    }
    assert any("SET status = 'completed'" in s for s in _sql(conn))


def test_baby_profile_job_never_touches_the_owners_user_avatar(gcs):
    _photos, _exports, prefix = gcs
    baby_id = uuid.uuid4()
    conn = _conn(_job("baby_profile_delete", baby_id))
    with patch("lanonna_worker.storage_cleanup.get_connection") as ctx:
        ctx.return_value.__enter__.return_value = conn
        run_storage_cleanup(uuid.uuid4())

    assert {c.args[1] for c in prefix.call_args_list} == {
        f"avatars/babies/{baby_id}/",
        f"exports/{baby_id}/",
    }


def test_unclaimable_job_is_skipped(gcs):
    photos, _exports, _prefix = gcs
    conn = _conn(None)  # missing, completed, failed, or running elsewhere
    with patch("lanonna_worker.storage_cleanup.get_connection") as ctx:
        ctx.return_value.__enter__.return_value = conn
        run_storage_cleanup(uuid.uuid4())

    photos.assert_not_called()


@pytest.mark.parametrize(
    ("final_attempt", "expected"),
    [(False, "SET status = 'pending'"), (True, "SET status = 'failed'")],
)
def test_gcs_failure_releases_or_fails_the_job(gcs, final_attempt, expected):
    photos, _exports, _prefix = gcs
    photos.side_effect = GcsDeleteError("boom")
    conn = _conn(_job("account_delete", uuid.uuid4()))
    with patch("lanonna_worker.storage_cleanup.get_connection") as ctx:
        ctx.return_value.__enter__.return_value = conn
        with pytest.raises(GcsDeleteError):
            run_storage_cleanup(uuid.uuid4(), final_attempt=final_attempt)

    assert any(expected in s for s in _sql(conn))
    assert not any("SET status = 'completed'" in s for s in _sql(conn))


def test_sweep_requeues_stuck_jobs_and_runs_each():
    conn = MagicMock()
    ids = [uuid.uuid4(), uuid.uuid4()]
    conn.execute.return_value.fetchall.return_value = [{"id": i} for i in ids]
    with (
        patch("lanonna_worker.storage_cleanup.get_connection") as ctx,
        patch(
            "lanonna_worker.storage_cleanup.run_storage_cleanup",
            side_effect=[GcsDeleteError("x"), None],
        ) as run,
    ):
        ctx.return_value.__enter__.return_value = conn
        assert sweep_storage_cleanup_jobs() == 2

    sql = " ".join(conn.execute.call_args.args[0].split())
    assert "FOR UPDATE SKIP LOCKED" in sql
    assert "status = 'failed'" in sql and "status = 'running'" in sql
    assert [c.args[0] for c in run.call_args_list] == ids


def test_delete_object_treats_not_found_as_done():
    client = MagicMock()
    client.bucket.return_value.blob.return_value.delete.side_effect = NotFound("gone")
    with patch("lanonna_worker.gcs_delete._client", return_value=client):
        assert gcs_delete.delete_object("b", "display/x.jpg") is False


def test_delete_photo_paths_derives_thumbnail_for_unprocessed_photo():
    photo_id = uuid.uuid4()
    with patch("lanonna_worker.gcs_delete.delete_object", return_value=True) as delete:
        assert gcs_delete.delete_photo_paths(f"display/{photo_id}.webp", None) == 2
    assert delete.call_args_list[1].args[1] == f"thumbnails/{photo_id}.jpg"


@pytest.mark.parametrize(
    "prefix", ["", "avatars/", "avatars/users//", "avatars/users/u1", "/x/"]
)
def test_delete_prefix_rejects_anything_but_an_owned_folder(prefix):
    with pytest.raises(ValueError):
        gcs_delete.delete_prefix("b", prefix)
