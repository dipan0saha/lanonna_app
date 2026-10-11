"""Search SQL must reference real columns (H-10: name_suggestions uses suggested_name)."""

import re
import uuid
from pathlib import Path
from unittest.mock import MagicMock, patch

from lanonna_api.repositories.search import search_name_suggestions

_MIGRATIONS = Path(__file__).resolve().parents[3] / "infra" / "db" / "migrations"


def _create_table_columns(table: str) -> set[str]:
    """Column names declared in the CREATE TABLE statement for ``table`` across migrations."""
    columns: set[str] = set()
    for path in sorted(_MIGRATIONS.glob("*.sql")):
        text = path.read_text()
        match = re.search(
            rf"CREATE TABLE IF NOT EXISTS {table}\s*\((.*?)\n\);",
            text,
            re.DOTALL,
        )
        if match:
            for line in match.group(1).splitlines():
                token = line.strip().split(" ")[0]
                if token and token.isidentifier() and token.upper() not in {
                    "PRIMARY",
                    "UNIQUE",
                    "CONSTRAINT",
                    "FOREIGN",
                    "CHECK",
                }:
                    columns.add(token)
    return columns


def test_search_name_suggestions_uses_existing_column():
    assert "suggested_name" in _create_table_columns("name_suggestions")
    assert "name" not in _create_table_columns("name_suggestions")

    conn = MagicMock()
    conn.execute.return_value.fetchall.return_value = [
        {"id": uuid.uuid4(), "name": "Liam"},
    ]
    with patch("lanonna_api.repositories.search.get_connection") as get_conn:
        get_conn.return_value.__enter__.return_value = conn
        rows = search_name_suggestions(uuid.uuid4(), "%li%", 5)

    sql = " ".join(conn.execute.call_args[0][0].split())
    assert "suggested_name ILIKE" in sql
    assert "suggested_name AS name" in sql
    assert rows == [{"id": rows[0]["id"], "name": "Liam"}]
