from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.main import app


def test_app_version_android():
    client = TestClient(app)
    with patch(
        "lanonna_api.routers.app_config.get_app_version_requirement",
        return_value={
            "platform": "android",
            "minimum_version": "1.0.0",
            "store_url": "https://example.com/android",
        },
    ):
        response = client.get("/v1/app/version", params={"platform": "android"})
    assert response.status_code == 200
    body = response.json()
    assert body["minimum_version"] == "1.0.0"
    assert body["store_url"] == "https://example.com/android"


def test_app_version_not_configured():
    client = TestClient(app)
    with patch(
        "lanonna_api.routers.app_config.get_app_version_requirement",
        return_value=None,
    ):
        response = client.get("/v1/app/version", params={"platform": "ios"})
    assert response.status_code == 404
