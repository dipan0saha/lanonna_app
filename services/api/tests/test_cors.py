from fastapi.testclient import TestClient

from lanonna_api.config import Settings
from lanonna_api.main import app


def test_cors_allow_origins_list_parses_comma_separated():
    settings = Settings(cors_allow_origins="https://a.com, https://b.com")
    assert settings.cors_allow_origins_list() == [
        "https://a.com",
        "https://b.com",
    ]


def test_cors_disabled_by_default_on_health_preflight():
    client = TestClient(app)
    response = client.options(
        "/health",
        headers={
            "Origin": "https://example.com",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert "access-control-allow-origin" not in {
        k.lower() for k in response.headers.keys()
    }
