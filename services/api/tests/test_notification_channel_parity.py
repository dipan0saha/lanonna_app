import ast
from pathlib import Path

from lanonna_api.domain.notifications import NotificationChannel

WORKER_NOTIFICATIONS = (
    Path(__file__).resolve().parents[2]
    / "worker/src/lanonna_worker/notifications.py"
)


def _worker_channel_columns() -> dict[str, str]:
    tree = ast.parse(WORKER_NOTIFICATIONS.read_text(encoding="utf-8"))
    for node in tree.body:
        if isinstance(node, ast.Assign):
            targets = node.targets
            value_node = node.value
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            targets = [node.target]
            value_node = node.value
        else:
            continue
        for target in targets:
            if isinstance(target, ast.Name) and target.id == "_CHANNEL_COLUMNS":
                value = ast.literal_eval(value_node)
                if isinstance(value, dict):
                    return value
    raise AssertionError("_CHANNEL_COLUMNS not found in worker notifications.py")


def test_notification_channel_enum_matches_worker_columns():
    worker_map = _worker_channel_columns()
    api_values = {channel.value for channel in NotificationChannel}
    assert set(worker_map.keys()) == api_values
    for channel in NotificationChannel:
        assert worker_map[channel.value].startswith("notify_")
        assert worker_map[channel.value] == f"notify_{channel.value}_enabled"
