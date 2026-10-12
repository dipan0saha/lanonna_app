from __future__ import annotations


def escape_ilike_literal(s: str) -> str:
    """Escape user input for PostgreSQL ILIKE … ESCAPE '\\'."""
    return (
        s.replace("\\", "\\\\")
        .replace("%", "\\%")
        .replace("_", "\\_")
    )


def ilike_substring_pattern(q: str) -> str:
    return f"%{escape_ilike_literal(q)}%"
