"""Fun hub writes (names and predictions) close when the baby is born.

Single source of truth for the "fun closed" rule. Read payloads should derive
their closed flags from ``fun_writes_closed`` so the API and the app agree.
"""

from __future__ import annotations

from typing import Any

from lanonna_api.domain.errors import ConflictError, ErrorCode


def fun_writes_closed(membership: dict[str, Any]) -> bool:
    return (membership.get("lifecycle_status") or "expecting") == "born"


def fun_closed_flags(membership: dict[str, Any]) -> dict[str, bool]:
    closed = fun_writes_closed(membership)
    return {"names_closed": closed, "predictions_closed": closed}


class FunWritesClosedError(ConflictError):
    """Base for fun-hub writes rejected after birth (mapped to HTTP 409)."""

    code_value = ErrorCode.FUN_CLOSED
    default_message = "Fun is closed — baby has arrived"

    def __init__(self) -> None:
        super().__init__(self.code_value, self.default_message)


class FunClosedError(FunWritesClosedError):
    """Name suggestions and likes cannot change after birth."""


class PredictionsClosedError(FunWritesClosedError):
    """Gender and birthdate votes cannot be created or changed."""

    code_value = ErrorCode.PREDICTIONS_CLOSED
    default_message = "Predictions closed — baby has arrived"


def ensure_fun_writes_open(
    membership: dict[str, Any],
    error: type[FunWritesClosedError] = FunClosedError,
) -> None:
    if fun_writes_closed(membership):
        raise error()
