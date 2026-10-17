from __future__ import annotations

from lanonna_api.domain.errors import DomainError, ErrorCode

_STATUS_BY_CODE: dict[ErrorCode, int] = {
    ErrorCode.MEMBERSHIP_ENDED: 403,
    ErrorCode.NOT_MEMBER: 404,
    ErrorCode.TARGET_NOT_MEMBER: 404,
}


class MemberLifecycleError(DomainError):
    """Membership remove/leave policy violation (400 unless the code says otherwise)."""

    def __init__(self, code: ErrorCode, message: str) -> None:
        super().__init__(code, message)
        self.status_code = _STATUS_BY_CODE.get(code, 400)
