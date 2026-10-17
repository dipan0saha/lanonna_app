from lanonna_api.http_errors import map_domain_errors
from lanonna_api.request_context import set_request_id


def test_map_domain_errors_permission_error_returns_json_detail():
    http_exc = map_domain_errors(PermissionError("Baby membership required."))
    assert http_exc.status_code == 403
    assert http_exc.detail == {
        "error": "forbidden",
        "message": "Baby membership required.",
    }


def test_map_domain_errors_hides_unexpected_exception_message():
    set_request_id("req-test-123")
    http_exc = map_domain_errors(TypeError("internal db leak"))
    assert http_exc.status_code == 500
    assert "secret" not in str(http_exc.detail)
    assert "req-test-123" in str(http_exc.detail)


import pytest
from fastapi.testclient import TestClient

from lanonna_api.domain.errors import (
    ErrorCode,
    ForbiddenError,
    InvalidInputError,
    NotFoundError,
)
from lanonna_api.domain.fun_closed import PredictionsClosedError
from lanonna_api.domain.member_errors import MemberLifecycleError
from lanonna_api.domain.user_errors import UserDeletedError
from lanonna_api.http_errors import api_error, normalize_error_detail
from lanonna_api.main import app


@pytest.mark.parametrize(
    ("exc", "status", "code"),
    [
        (PermissionError("x"), 403, "forbidden"),
        (LookupError("x"), 404, "not_found"),
        (ValueError("x"), 400, "invalid_request"),
        (RuntimeError("x"), 503, "service_unavailable"),
        (InvalidInputError(ErrorCode.COMMENT_REQUIRED, "x"), 400, "comment_required"),
        (ForbiddenError(ErrorCode.REGISTRY_ITEM_PURCHASED, "x"), 403, "registry_item_purchased"),
        (NotFoundError(ErrorCode.NOT_FOUND, "x"), 404, "not_found"),
        (PredictionsClosedError(), 409, "predictions_closed"),
        (UserDeletedError(), 401, "user_deleted"),
        (MemberLifecycleError(ErrorCode.MEMBERSHIP_ENDED, "x"), 403, "membership_ended"),
        (MemberLifecycleError(ErrorCode.NOT_MEMBER, "x"), 404, "not_member"),
        (MemberLifecycleError(ErrorCode.LAST_OWNER, "x"), 400, "last_owner"),
    ],
)
def test_every_mapped_error_carries_a_code_and_diagnostic_message(exc, status, code):
    http_exc = map_domain_errors(exc)
    assert http_exc.status_code == status
    assert http_exc.detail["error"] == code
    assert isinstance(http_exc.detail["message"], str)


def test_typed_errors_still_satisfy_builtin_handlers():
    assert isinstance(InvalidInputError(ErrorCode.NAME_REQUIRED, "x"), ValueError)
    assert isinstance(ForbiddenError(ErrorCode.FORBIDDEN, "x"), PermissionError)
    assert isinstance(NotFoundError(ErrorCode.NOT_FOUND, "x"), LookupError)


def test_params_travel_with_the_code():
    exc = InvalidInputError(ErrorCode.TEXT_TOO_LONG, "x", params={"max_length": 80})
    assert map_domain_errors(exc).detail["params"] == {"max_length": 80}


def test_plain_string_details_are_normalized_by_status():
    assert normalize_error_detail(404, "Not found") == {
        "error": "not_found",
        "message": "Not found",
    }
    assert normalize_error_detail(429, "slow down")["error"] == "rate_limited"
    assert normalize_error_detail(502, None)["error"] == "internal_error"
    coded = api_error(400, ErrorCode.INVALID_URL, "bad").detail
    assert normalize_error_detail(400, coded) == coded


def test_framework_errors_reach_clients_with_codes():
    client = TestClient(app)
    missing = client.get("/v1/does-not-exist")
    assert missing.status_code == 404
    assert missing.json()["detail"]["error"] == "not_found"

    invalid = client.get("/v1/app/version", params={"platform": "web"})
    assert invalid.status_code == 422
    detail = invalid.json()["detail"]
    assert detail["error"] == "invalid_request"
    assert detail["fields"] and detail["message"]
