from unittest.mock import patch

import pytest
from fastapi import HTTPException

from lanonna_api import auth as auth_module
from lanonna_api.auth import verify_firebase_token
from lanonna_api.config import Settings


@pytest.fixture
def lanonna_dev_settings():
    original = auth_module.settings
    auth_module.settings = Settings(gcp_project_id="lanonna-dev", firebase_audiences="")
    try:
        yield
    finally:
        auth_module.settings = original


def test_verify_firebase_token_rejects_wrong_audience(lanonna_dev_settings):
    with patch(
        "lanonna_api.auth.firebase_auth.verify_id_token",
        return_value={"aud": "other-project", "uid": "u1"},
    ):
        with pytest.raises(HTTPException) as raised:
            verify_firebase_token("token")
    assert raised.value.status_code == 401


def test_verify_firebase_token_accepts_project_audience(lanonna_dev_settings):
    with patch(
        "lanonna_api.auth.firebase_auth.verify_id_token",
        return_value={"aud": "lanonna-dev", "uid": "u1"},
    ):
        claims = verify_firebase_token("token")
    assert claims["uid"] == "u1"
