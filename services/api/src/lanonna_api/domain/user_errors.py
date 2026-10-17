from lanonna_api.domain.errors import ErrorCode, UnauthenticatedError


class UserDeletedError(UnauthenticatedError):
    """Raised when a Firebase UID maps to a tombstoned app_users row (NFR-DATA-001)."""

    def __init__(self) -> None:
        super().__init__(ErrorCode.USER_DELETED, "This account was deleted.")
