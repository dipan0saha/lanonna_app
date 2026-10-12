"""Provisioning stays in one dependency (#36)."""

import ast
from pathlib import Path

_SRC = Path(__file__).resolve().parents[1] / "src" / "lanonna_api"
_ALLOW_CURRENT_USER = {"post_delete_account"}


def _depends_name(node: ast.AST) -> str | None:
    if not isinstance(node, ast.Call):
        return None
    func = node.func
    if not isinstance(func, ast.Name) or func.id != "Depends":
        return None
    if not node.args or not isinstance(node.args[0], ast.Name):
        return None
    return node.args[0].id


def test_upsert_app_user_is_gone():
    for path in _SRC.rglob("*.py"):
        assert "upsert_app_user" not in path.read_text(), path


def test_resolve_app_user_is_only_called_from_auth():
    offenders: list[str] = []
    for path in _SRC.rglob("*.py"):
        if path.name == "users.py" and path.parent.name == "repositories":
            continue
        if path.name == "auth.py":
            continue
        tree = ast.parse(path.read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.Name) and node.id == "resolve_app_user":
                offenders.append(f"{path}:{node.lineno}")
            if isinstance(node, ast.Attribute) and node.attr == "resolve_app_user":
                offenders.append(f"{path}:{node.lineno}")
    assert offenders == []


def test_authenticated_handlers_use_current_app_user():
    roots = [_SRC / "routers", _SRC / "main.py"]
    files: list[Path] = []
    for root in roots:
        if root.is_file():
            files.append(root)
        else:
            files.extend(root.glob("*.py"))
    mistakes: list[str] = []
    for path in files:
        tree = ast.parse(path.read_text())
        for node in ast.walk(tree):
            if not isinstance(node, ast.FunctionDef):
                continue
            names = [
                _depends_name(default)
                for default in node.args.defaults
                if _depends_name(default)
            ]
            if "current_user" in names and node.name not in _ALLOW_CURRENT_USER:
                mistakes.append(f"{path.name}:{node.name} depends on current_user")
            if "current_user" in names and "current_app_user" in names:
                mistakes.append(f"{path.name}:{node.name} depends on both")
    assert mistakes == []
