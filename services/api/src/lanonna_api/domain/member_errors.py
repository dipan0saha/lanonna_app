class MemberLifecycleError(Exception):
    """Membership remove/leave policy violation."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
