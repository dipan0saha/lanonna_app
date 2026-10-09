import uuid
from unittest.mock import MagicMock, patch

from lanonna_api.repositories.photo_tags import list_tagged_babies_for_photo


def test_list_tagged_babies_for_photo_scopes_by_viewer_membership():
    photo_id = uuid.uuid4()
    viewer_uid = "follower-uid"
    conn = MagicMock()
    conn.execute.return_value.fetchall.return_value = []

    with patch(
        "lanonna_api.repositories.photo_tags.get_connection"
    ) as get_conn:
        get_conn.return_value.__enter__.return_value = conn
        list_tagged_babies_for_photo(photo_id, viewer_uid)

    sql, params = conn.execute.call_args[0]
    assert "baby_memberships" in sql
    assert "m.firebase_uid = %s" in sql
    assert params == (viewer_uid, photo_id)
