"""The shared GCS URL signer: one backend, cached read URLs, parallel misses."""

from __future__ import annotations

import threading
from datetime import timedelta

import pytest

from lanonna_api.storage import (
    READ_URL_REUSE,
    READ_URL_TTL,
    UPLOAD_URL_TTL,
    GcsUrlSigner,
)


class FakeBackend:
    def __init__(self) -> None:
        self.calls: list[dict] = []
        self.threads: set[str] = set()
        self._lock = threading.Lock()
        self._n = 0

    def sign(self, bucket, object_name, *, method, expiration, content_type=None, headers=None):
        with self._lock:
            self._n += 1
            n = self._n
            self.calls.append(
                {
                    "bucket": bucket,
                    "object": object_name,
                    "method": method,
                    "expiration": expiration,
                    "content_type": content_type,
                    "headers": headers,
                }
            )
            self.threads.add(threading.current_thread().name)
        return f"https://signed/{bucket}/{object_name}?sig={n}"


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def _signer(**kwargs):
    backend = FakeBackend()
    clock = Clock()
    factory_calls = []

    def factory():
        factory_calls.append(1)
        return backend

    signer = GcsUrlSigner(factory, clock=clock, **kwargs)
    return signer, backend, clock, factory_calls


def test_read_url_ttl_is_unchanged_and_reuse_is_well_under_it():
    assert READ_URL_TTL == timedelta(seconds=900)
    assert UPLOAD_URL_TTL == timedelta(seconds=900)
    # A served URL always has at least two thirds of its life left.
    assert READ_URL_TTL - READ_URL_REUSE >= timedelta(seconds=600)


def test_backend_is_built_lazily_once():
    signer, _, _, factory_calls = _signer()
    assert factory_calls == []
    signer.read_url("b", "a.jpg")
    signer.read_url("b", "c.jpg")
    signer.upload_url("b", "d.jpg", content_type="image/jpeg", headers={})
    assert factory_calls == [1]


def test_read_url_is_signed_once_and_reused_within_the_window():
    signer, backend, clock, _ = _signer()
    first = signer.read_url("thumbs", "p1.jpg")
    clock.now += READ_URL_REUSE.total_seconds() - 1
    assert signer.read_url("thumbs", "p1.jpg") == first
    assert len(backend.calls) == 1
    call = backend.calls[0]
    assert (call["method"], call["expiration"]) == ("GET", READ_URL_TTL)


def test_read_url_is_re_signed_after_the_reuse_window():
    signer, backend, clock, _ = _signer()
    first = signer.read_url("thumbs", "p1.jpg")
    clock.now += READ_URL_REUSE.total_seconds()
    second = signer.read_url("thumbs", "p1.jpg")
    assert second != first
    assert len(backend.calls) == 2


def test_cache_is_keyed_by_bucket_and_object():
    signer, backend, _, _ = _signer()
    a = signer.read_url("display", "x.webp")
    b = signer.read_url("thumbs", "x.webp")
    assert a != b
    assert len(backend.calls) == 2


def test_read_urls_keeps_order_dedupes_and_signs_only_misses():
    signer, backend, _, _ = _signer()
    signer.read_url("t", "cached.jpg")
    refs = [("t", "a.jpg"), ("t", "cached.jpg"), ("t", "b.jpg"), ("t", "a.jpg")]
    urls = signer.read_urls(refs)
    assert [u.split("?")[0] for u in urls] == [f"https://signed/t/{o}" for _, o in refs]
    assert urls[0] == urls[3]
    signed_objects = sorted(c["object"] for c in backend.calls)
    assert signed_objects == ["a.jpg", "b.jpg", "cached.jpg"]


def test_misses_are_signed_in_parallel_on_the_signer_pool():
    signer, backend, _, _ = _signer(concurrency=4)
    signer.read_urls([("t", f"{i}.jpg") for i in range(20)])
    assert len(backend.calls) == 20
    assert backend.threads and all(t.startswith("gcs-sign") for t in backend.threads)


def test_cache_is_bounded_lru():
    signer, backend, _, _ = _signer(max_entries=2)
    signer.read_url("t", "a")
    signer.read_url("t", "b")
    signer.read_url("t", "a")  # a is now most recent
    signer.read_url("t", "c")  # evicts b
    calls = len(backend.calls)
    signer.read_url("t", "a")
    assert len(backend.calls) == calls
    signer.read_url("t", "b")
    assert len(backend.calls) == calls + 1


def test_upload_urls_are_never_cached():
    signer, backend, _, _ = _signer()
    headers = {"x-goog-content-length-range": "0,10"}
    signer.upload_url("display", "display/p.webp", content_type="image/webp", headers=headers)
    signer.upload_url("display", "display/p.webp", content_type="image/webp", headers=headers)
    assert len(backend.calls) == 2
    call = backend.calls[0]
    assert call["method"] == "PUT"
    assert call["expiration"] == UPLOAD_URL_TTL
    assert call["content_type"] == "image/webp"
    assert call["headers"] == headers


def test_signing_errors_propagate_and_are_not_cached():
    calls = []

    class Failing(FakeBackend):
        def sign(self, *a, **k):
            calls.append(1)
            if len(calls) == 1:
                raise RuntimeError("iam down")
            return super().sign(*a, **k)

    signer = GcsUrlSigner(Failing, clock=Clock())
    with pytest.raises(RuntimeError, match="iam down"):
        signer.read_url("t", "a.jpg")
    assert signer.read_url("t", "a.jpg").startswith("https://signed/t/a.jpg")


def test_reuse_must_be_shorter_than_ttl():
    with pytest.raises(ValueError):
        GcsUrlSigner(FakeBackend, read_ttl=timedelta(seconds=60), read_reuse=timedelta(seconds=60))


def test_iam_backend_builds_v4_url_with_unchanged_expiry_and_one_client(monkeypatch):
    """The real backend, with IAM signBlob replaced by a local fake signer."""
    import google.auth
    from google.auth import iam
    from google.auth.credentials import AnonymousCredentials

    from lanonna_api.storage import IamSigningBackend

    sign_calls = []

    class FakeIamSigner:
        def __init__(self, request, credentials, service_account_email):
            self.key_id = None
            self.request = request

        def sign(self, message):
            sign_calls.append(message)
            return b"\x01" * 256

    defaults = []

    def fake_default(scopes=None):
        defaults.append(scopes)
        return AnonymousCredentials(), "lanonna-dev"

    monkeypatch.setattr(google.auth, "default", fake_default)
    monkeypatch.setattr(iam, "Signer", FakeIamSigner)

    backend = IamSigningBackend("lanonna-dev", "signer@lanonna-dev.iam.gserviceaccount.com")
    read = backend.sign("thumbs", "babies/x/p.jpg", method="GET", expiration=READ_URL_TTL)
    put = backend.sign(
        "display",
        "babies/x/p.webp",
        method="PUT",
        expiration=UPLOAD_URL_TTL,
        content_type="image/webp",
        headers={"x-goog-content-length-range": "0,10"},
    )

    assert len(defaults) == 1  # credentials resolved once per process
    assert len(sign_calls) == 2
    for url in (read, put):
        assert "X-Goog-Algorithm=GOOG4-RSA-SHA256" in url
        assert "X-Goog-Expires=900" in url
        assert "signer%40lanonna-dev.iam.gserviceaccount.com" in url
    assert read.startswith("https://storage.googleapis.com/thumbs/babies/x/p.jpg?")
