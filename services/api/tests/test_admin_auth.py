from unittest.mock import patch

from lanonna_api.admin_auth import require_admin_api_key
from fastapi import HTTPException


def test_require_admin_api_key_rejects_missing():
    with patch("lanonna_api.admin_auth.settings.admin_api_key", "secret"):
        try:
            require_admin_api_key(x_admin_key=None)
            assert False, "expected HTTPException"
        except HTTPException as exc:
            assert exc.status_code == 401


def test_require_admin_api_key_accepts_valid():
    with patch("lanonna_api.admin_auth.settings.admin_api_key", "secret"):
        require_admin_api_key(x_admin_key="secret")
