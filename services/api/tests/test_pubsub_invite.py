import uuid
from unittest.mock import MagicMock, patch

from lanonna_api.pubsub import publish_send_invite_email


@patch("lanonna_api.pubsub._publisher_client")
def test_publish_send_invite_email_omits_invite_token(mock_client_fn):
    client = MagicMock()
    future = MagicMock()
    client.publish.return_value = future
    mock_client_fn.return_value = client
    client.topic_path.return_value = "projects/p/topics/t"

    inv_id = uuid.uuid4()
    publish_send_invite_email(inv_id)

    published = client.publish.call_args[0][1].decode("utf-8")
    assert "invite_token" not in published
    assert str(inv_id) in published
