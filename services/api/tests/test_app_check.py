from unittest.mock import patch

import pytest
from fastapi import HTTPException

from lanonna_api.app_check import require_app_check


class _FakeRequest:
    def __init__(self, headers: dict[str, str]) -> None:
        self.headers = headers
        self.url = type("U", (), {"path": "/v1/me"})()


def test_require_app_check_allows_missing_when_not_enforced():
    with patch("lanonna_api.app_check.settings") as settings:
        settings.app_check_enforce = False
        require_app_check(_FakeRequest({}))


def test_require_app_check_rejects_missing_when_enforced():
    with patch("lanonna_api.app_check.settings") as settings:
        settings.app_check_enforce = True
        with pytest.raises(HTTPException) as exc:
            require_app_check(_FakeRequest({}))
        assert exc.value.status_code == 401
