from lanonna_api.http_errors import map_domain_errors
from lanonna_api.request_context import set_request_id


def test_map_domain_errors_hides_unexpected_exception_message():
    set_request_id("req-test-123")
    http_exc = map_domain_errors(TypeError("internal db leak"))
    assert http_exc.status_code == 500
    assert "secret" not in str(http_exc.detail)
    assert "req-test-123" in str(http_exc.detail)
