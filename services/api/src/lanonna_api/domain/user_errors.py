class UserDeletedError(Exception):
    """Raised when a Firebase UID maps to a tombstoned app_users row (NFR-DATA-001)."""
