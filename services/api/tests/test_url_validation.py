import pytest

from lanonna_api.domain.url_validation import (
    INVALID_HTTP_URL,
    normalize_optional_http_url,
)


def test_empty_optional_url():
    assert normalize_optional_http_url(None) is None
    assert normalize_optional_http_url("") is None
    assert normalize_optional_http_url("   ") is None


def test_accepts_https():
    assert (
        normalize_optional_http_url("https://example.com/item")
        == "https://example.com/item"
    )


@pytest.mark.parametrize(
    "value",
    [
        "http://example.com",
        "http://localhost/shop",
        "http://127.0.0.1:8080/x",
        "https://localhost/shop",
        "localhost:8080",
    ],
)
def test_links_are_https_on_a_real_host_in_every_environment(value):
    with pytest.raises(ValueError, match=INVALID_HTTP_URL):
        normalize_optional_http_url(value)


def test_bare_domain_gets_https_prefix():
    assert (
        normalize_optional_http_url("amazon.com/x")
        == "https://amazon.com/x"
    )


def test_rejects_invalid_values():
    for bad in (
        "not-a-url",
        "javascript:alert(1)",
        "ftp://files.example.com/x",
        "https://",
        "://example.com",
        "https://example.com:port/x",
    ):
        with pytest.raises(ValueError, match=INVALID_HTTP_URL):
            normalize_optional_http_url(bad)
