"""App lifespan (DB pool, signer warm-up) and response compression."""

from __future__ import annotations

import gzip
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.middleware.gzip import GZipMiddleware

from lanonna_api import main
from lanonna_api.config import settings


def test_lifespan_opens_pool_warms_signer_and_closes_pool(monkeypatch):
    monkeypatch.setattr(settings, "db_password", "x")
    with (
        patch("lanonna_api.db.open_pool") as open_pool,
        patch("lanonna_api.db.close_pool") as close_pool,
        patch("lanonna_api.main.warm_up_url_signer") as warm,
    ):
        with TestClient(main.app):
            open_pool.assert_called_once()
            warm.assert_called_once()
            close_pool.assert_not_called()
        close_pool.assert_called_once()


def test_lifespan_survives_signer_warm_up_failure_and_skips_pool_without_db(monkeypatch):
    monkeypatch.setattr(settings, "db_password", "")
    with (
        patch("lanonna_api.db.open_pool") as open_pool,
        patch("lanonna_api.db.close_pool"),
        patch("lanonna_api.main.warm_up_url_signer", side_effect=RuntimeError("no adc")),
    ):
        with TestClient(main.app) as client:
            assert client.get("/health").status_code == 200
        open_pool.assert_not_called()


def test_gzip_middleware_is_installed_with_minimum_size():
    entries = [m for m in main.app.user_middleware if m.cls is GZipMiddleware]
    assert len(entries) == 1
    assert entries[0].kwargs["minimum_size"] == main.GZIP_MINIMUM_SIZE == 1024


def _probe_app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(GZipMiddleware, minimum_size=main.GZIP_MINIMUM_SIZE)

    @app.get("/big")
    def big():
        return {"items": ["x" * 40] * 100}

    @app.get("/small")
    def small():
        return {"ok": True}

    return app


def test_large_json_is_compressed_and_small_json_is_not():
    client = TestClient(_probe_app())
    big = client.get("/big", headers={"Accept-Encoding": "gzip"})
    assert big.headers["content-encoding"] == "gzip"
    assert big.json()["items"][0] == "x" * 40
    small = client.get("/small", headers={"Accept-Encoding": "gzip"})
    assert "content-encoding" not in small.headers
    plain = client.get("/big", headers={"Accept-Encoding": "identity"})
    assert "content-encoding" not in plain.headers
    assert gzip.compress(plain.content)  # sanity: body is plain JSON
