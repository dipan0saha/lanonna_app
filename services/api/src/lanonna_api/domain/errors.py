"""Stable error codes and typed domain errors.

Every API error body is ``{"detail": {"error": <code>, "message": <English>}}``
(plus optional ``params``). The **code** is the contract: the app maps it to
localized copy (``apps/mobile/lib/core/api/api_error_code.dart``, kept in sync
by ``tests/test_error_code_parity.py``). The English ``message`` is for logs and
debugging only and is never shown to users.

Domain code raises:

- a builtin ``PermissionError`` / ``LookupError`` / ``ValueError`` /
  ``RuntimeError`` when the generic copy for that category is right
  (``forbidden`` / ``not_found`` / ``invalid_request`` / ``service_unavailable``);
- a typed :class:`DomainError` subclass when the user needs specific copy.

``http_errors.map_domain_errors`` is the single place that turns either into HTTP.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Any


class ErrorCode(StrEnum):
    # Generic categories (status-derived fallbacks).
    INTERNAL_ERROR = "internal_error"
    SERVICE_UNAVAILABLE = "service_unavailable"
    INVALID_REQUEST = "invalid_request"
    NOT_FOUND = "not_found"
    FORBIDDEN = "forbidden"
    CONFLICT = "conflict"
    UNAUTHENTICATED = "unauthenticated"
    APP_CHECK_FAILED = "app_check_failed"
    RATE_LIMITED = "rate_limited"
    # Session and membership.
    USER_DELETED = "user_deleted"
    MEMBERSHIP_ENDED = "membership_ended"
    NOT_MEMBER = "not_member"
    TARGET_NOT_MEMBER = "target_not_member"
    LAST_OWNER = "last_owner"
    SOLE_OWNER_CANNOT_LEAVE = "sole_owner_cannot_leave"
    USE_LEAVE_ENDPOINT = "use_leave_endpoint"
    CANNOT_DELETE_SHARED_BABY = "cannot_delete_shared_baby"
    # Invitation accept (``POST /v1/invitations/accept``).
    EXPIRED = "expired"
    REVOKED = "revoked"
    ALREADY_USED = "already_used"
    MAX_OWNERS = "max_owners"
    EMAIL_MISMATCH = "email_mismatch"
    # Onboarding.
    EMAIL_NOT_VERIFIED = "email_not_verified"
    BABY_PROFILE_REQUIRED = "baby_profile_required"
    PROFILE_INCOMPLETE = "profile_incomplete"
    # Profile and shared field validation.
    DISPLAY_NAME_REQUIRED = "display_name_required"
    INVALID_PHONE = "invalid_phone"
    INVALID_BIRTH_DATE = "invalid_birth_date"
    BIRTH_DATE_IN_FUTURE = "birth_date_in_future"
    INVALID_URL = "invalid_url"
    INVALID_STORAGE_REFERENCE = "invalid_storage_reference"
    TEXT_TOO_LONG = "text_too_long"
    INVALID_BIRTH_TIME = "invalid_birth_time"
    COMMENT_REQUIRED = "comment_required"
    # Uploads.
    UNSUPPORTED_MEDIA_TYPE = "unsupported_media_type"
    FILE_TOO_LARGE = "file_too_large"
    # Fun hub.
    FUN_CLOSED = "fun_closed"
    PREDICTIONS_CLOSED = "predictions_closed"
    BIRTHDATE_VOTE_OUT_OF_RANGE = "birthdate_vote_out_of_range"
    NAME_REQUIRED = "name_required"
    DUPLICATE_NAME_SUGGESTION = "duplicate_name_suggestion"
    NAME_ALREADY_SUGGESTED = "name_already_suggested"
    # Registry.
    ITEM_NAME_REQUIRED = "item_name_required"
    ALREADY_ON_REGISTRY = "already_on_registry"
    REGISTRY_ITEM_PURCHASED = "registry_item_purchased"
    SHIPPING_ADDRESS_INCOMPLETE = "shipping_address_incomplete"
    # Calendar.
    ALREADY_ON_CALENDAR = "already_on_calendar"
    EVENT_END_BEFORE_START = "event_end_before_start"
    # Biometric sign-in (``/v1/auth/biometric/*``). One code for every reason a
    # device credential cannot sign in, so the unauthenticated routes never say
    # which (missing, revoked, deleted or disabled account, revoked sessions).
    BIOMETRIC_CREDENTIAL_INVALID = "biometric_credential_invalid"
    BIOMETRIC_CHALLENGE_EXPIRED = "biometric_challenge_expired"
    # Invite management (``POST …/invitations/{id}/resend``).
    INVITE_ALREADY_DELIVERED = "invite_already_delivered"
    # Async work the API queues.
    EMAIL_QUEUE_FAILED = "email_queue_failed"
    EXPORT_QUEUE_FAILED = "export_queue_failed"


def error_detail(
    code: ErrorCode,
    message: str,
    params: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """The one JSON ``detail`` shape every API error uses."""
    detail: dict[str, Any] = {"error": ErrorCode(code).value, "message": message}
    if params:
        detail["params"] = params
    return detail


class DomainError(Exception):
    """A rule violation with a stable code; subclasses fix the HTTP status."""

    status_code = 400

    def __init__(
        self,
        code: ErrorCode,
        message: str,
        *,
        params: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = ErrorCode(code)
        self.message = message
        self.params = params

    def detail(self) -> dict[str, Any]:
        return error_detail(self.code, self.message, self.params)


# Each typed error also subclasses the builtin it replaces, so existing
# ``except ValueError`` / ``except PermissionError`` paths keep working.
class InvalidInputError(DomainError, ValueError):
    status_code = 400


class UnprocessableInputError(DomainError, ValueError):
    status_code = 422


class UnauthenticatedError(DomainError):
    status_code = 401


class ForbiddenError(DomainError, PermissionError):
    status_code = 403


class NotFoundError(DomainError, LookupError):
    status_code = 404


class ConflictError(DomainError):
    status_code = 409


class GoneError(DomainError):
    status_code = 410


class ServiceUnavailableError(DomainError, RuntimeError):
    status_code = 503
