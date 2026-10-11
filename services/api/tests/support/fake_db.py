"""Minimal stand-ins for psycopg connections used by repository SQL tests."""

from __future__ import annotations

from typing import Any, Callable


class RecordingConnection:
    """Context-manager connection that records ``execute`` calls and returns a canned cursor.

    ``executed`` receives ``(sql.strip(), params)`` for every statement so tests can assert on
    the generated SQL and bound parameters.
    """

    def __init__(self, cursor_factory: Callable[[], Any], executed: list[tuple]) -> None:
        self._cursor_factory = cursor_factory
        self._executed = executed

    def execute(self, sql: str, params: Any = None) -> Any:
        self._executed.append((sql.strip(), params))
        return self._cursor_factory()

    def __enter__(self) -> "RecordingConnection":
        return self

    def __exit__(self, *args: Any) -> bool:
        return False
