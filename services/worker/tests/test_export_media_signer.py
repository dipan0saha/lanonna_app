"""Export media links are signed through one process-wide signer."""

from __future__ import annotations

import google.auth
import pytest
from google.auth import iam
from google.auth.credentials import AnonymousCredentials

from lanonna_worker.export import media


@pytest.fixture(autouse=True)
def _fresh_signer():
    media.reset_export_signer()
    yield
    media.reset_export_signer()


def test_export_links_reuse_one_signer_with_seven_day_expiry(monkeypatch):
    defaults = []
    signed = []

    class FakeIamSigner:
        key_id = None

        def __init__(self, request, credentials, service_account_email):
            pass

        def sign(self, message):
            signed.append(message)
            return b"\x02" * 256

    def fake_default(scopes=None):
        defaults.append(scopes)
        return AnonymousCredentials(), "lanonna-dev"

    monkeypatch.setattr(google.auth, "default", fake_default)
    monkeypatch.setattr(iam, "Signer", FakeIamSigner)

    urls = [
        media.sign_export_read_url("lanonna-dev-display", f"babies/b/p{i}.webp")
        for i in range(3)
    ]

    assert len(defaults) == 1  # credentials and client built once
    assert len(signed) == 3
    for url in urls:
        assert "X-Goog-Expires=604800" in url
        assert "lanonna-worker%40lanonna-dev.iam.gserviceaccount.com" in url
