import uuid
from unittest.mock import MagicMock, patch

from lanonna_worker.thumbnails import process_gcs_finalize


@patch("lanonna_worker.thumbnails.process_notify_fan_out")
@patch("lanonna_worker.thumbnails.try_claim_photo_ready_notify", return_value=True)
@patch("lanonna_worker.thumbnails.get_connection")
@patch("lanonna_worker.thumbnails.mark_photo_ready")
@patch("lanonna_worker.thumbnails.storage.Client")
@patch("lanonna_worker.thumbnails.settings")
def test_process_gcs_finalize_happy_path(
    mock_settings,
    mock_client_cls,
    mock_mark_ready,
    mock_conn_ctx,
    _claim,
    mock_fan_out,
):
    photo_id = uuid.uuid4()
    baby_id = uuid.uuid4()
    display_name = f"display/{photo_id}.jpg"
    mock_settings.display_bucket = "display-bucket"
    mock_settings.thumbnails_bucket = "thumb-bucket"
    mock_settings.gcp_project_id = "proj"

    ready_row = {
        "id": photo_id,
        "baby_profile_id": baby_id,
        "uploader_firebase_uid": "uploader-1",
    }
    mock_mark_ready.return_value = ready_row

    conn = MagicMock()
    mock_conn_ctx.return_value.__enter__.return_value = conn

    display_blob = MagicMock()
    display_blob.exists.return_value = True
    display_blob.download_as_bytes.return_value = _minimal_jpeg_bytes()

    thumb_blob = MagicMock()
    bucket = MagicMock()
    bucket.blob.side_effect = lambda name: display_blob if name == display_name else thumb_blob
    mock_client_cls.return_value.bucket.return_value = bucket

    process_gcs_finalize(
        {
            "bucket": "display-bucket",
            "name": display_name,
            "generation": "99",
        }
    )

    mock_mark_ready.assert_called_once()
    call_kw = mock_mark_ready.call_args.kwargs
    assert call_kw["display_path"] == display_name
    assert call_kw["thumb_path"] == f"thumbnails/{photo_id}.jpg"
    assert call_kw["object_generation"] == 99

    mock_fan_out.assert_called_once()
    payload = mock_fan_out.call_args[0][0]
    assert payload["baby_profile_id"] == str(baby_id)
    assert payload["deep_link"] == f"/gallery/photo/{photo_id}"
    assert payload["notification_channel"] == "gallery"


@patch("lanonna_worker.thumbnails.mark_photo_ready")
@patch("lanonna_worker.thumbnails.storage.Client")
@patch("lanonna_worker.thumbnails.settings")
def test_process_gcs_finalize_skips_wrong_bucket_or_path(
    mock_settings,
    mock_client_cls,
    mock_mark_ready,
):
    mock_settings.display_bucket = "display-bucket"

    process_gcs_finalize({"bucket": "other-bucket", "name": "display/x.webp"})
    process_gcs_finalize({"bucket": "display-bucket", "name": "not-a-photo.txt"})

    mock_client_cls.assert_not_called()
    mock_mark_ready.assert_not_called()


@patch("lanonna_worker.thumbnails.process_notify_fan_out")
@patch("lanonna_worker.thumbnails.try_claim_photo_ready_notify", return_value=True)
@patch("lanonna_worker.thumbnails.get_connection")
@patch("lanonna_worker.thumbnails.get_ready_photo_by_display_path")
@patch("lanonna_worker.thumbnails.mark_photo_ready", return_value=None)
@patch("lanonna_worker.thumbnails.storage.Client")
@patch("lanonna_worker.thumbnails.settings")
def test_process_gcs_finalize_idempotent_ready_still_notifies(
    mock_settings,
    mock_client_cls,
    mock_mark_ready,
    mock_get_ready,
    mock_conn_ctx,
    _claim,
    mock_fan_out,
):
    photo_id = uuid.uuid4()
    baby_id = uuid.uuid4()
    display_name = f"display/{photo_id}.jpg"
    mock_settings.display_bucket = "display-bucket"
    mock_settings.thumbnails_bucket = "thumb-bucket"
    mock_settings.gcp_project_id = "proj"

    conn = MagicMock()
    mock_conn_ctx.return_value.__enter__.return_value = conn

    mock_get_ready.return_value = {
        "id": photo_id,
        "baby_profile_id": baby_id,
        "uploader_firebase_uid": "uploader-1",
        "display_object_generation": 7,
    }

    display_blob = MagicMock()
    display_blob.exists.return_value = True
    display_blob.download_as_bytes.return_value = _minimal_jpeg_bytes()
    thumb_blob = MagicMock()
    bucket = MagicMock()
    bucket.blob.side_effect = lambda name: display_blob if name == display_name else thumb_blob
    mock_client_cls.return_value.bucket.return_value = bucket

    process_gcs_finalize(
        {
            "bucket": "display-bucket",
            "name": display_name,
            "generation": "7",
        }
    )

    mock_get_ready.assert_called_once_with(display_name)
    mock_fan_out.assert_called_once()


def _minimal_jpeg_bytes() -> bytes:
    from PIL import Image
    import io

    img = Image.new("RGB", (8, 8), color=(255, 0, 0))
    out = io.BytesIO()
    img.save(out, format="JPEG")
    return out.getvalue()
