from __future__ import annotations

from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_worker import main
from lanonna_worker.config import settings


def test_lifespan_opens_and_closes_pool(monkeypatch):
    monkeypatch.setattr(settings, "db_password", "x")
    with (
        patch("lanonna_worker.db.open_pool") as open_pool,
        patch("lanonna_worker.db.close_pool") as close_pool,
    ):
        with TestClient(main.app) as client:
            assert client.get("/health").status_code == 200
            open_pool.assert_called_once()
        close_pool.assert_called_once()


def test_lifespan_without_db_skips_pool(monkeypatch):
    monkeypatch.setattr(settings, "db_password", "")
    with patch("lanonna_worker.db.open_pool") as open_pool, patch("lanonna_worker.db.close_pool"):
        with TestClient(main.app):
            pass
        open_pool.assert_not_called()
