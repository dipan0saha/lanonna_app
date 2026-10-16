"""Fun hub writes close when the baby is born."""

from __future__ import annotations

from typing import Any


def fun_writes_closed(membership: dict[str, Any]) -> bool:
    return (membership.get("lifecycle_status") or "expecting") == "born"


class FunClosedError(Exception):
    """Name suggestions and likes cannot change after birth."""

    code = "fun_closed"

    def __init__(self) -> None:
        self.message = "Fun is closed — baby has arrived"
        super().__init__(self.message)


def ensure_fun_writes_open(membership: dict[str, Any]) -> None:
    if fun_writes_closed(membership):
        raise FunClosedError()
