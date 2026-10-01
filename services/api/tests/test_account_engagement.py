from unittest.mock import patch

from lanonna_api.domain.account import build_account_extensions


def test_build_account_extensions_includes_engagement_no_storage_for_follower_only():
    with (
        patch(
            "lanonna_api.domain.account.list_babies_for_user",
            return_value=[{"role": "follower"}],
        ),
        patch(
            "lanonna_api.domain.account.count_engagement_for_user",
            return_value={
                "photos_squished": 2,
                "events_attended": 1,
                "items_bought": 0,
                "comments": 3,
            },
        ),
        patch("lanonna_api.domain.account.storage_usage_for_owner_babies") as storage_mock,
    ):
        data = build_account_extensions("uid")

    assert data["engagement"]["photos_squished"] == 2
    assert data["storage_usage"] is None
    storage_mock.assert_not_called()


def test_build_account_extensions_storage_when_owner():
    with (
        patch(
            "lanonna_api.domain.account.list_babies_for_user",
            return_value=[{"role": "owner"}],
        ),
        patch(
            "lanonna_api.domain.account.count_engagement_for_user",
            return_value={
                "photos_squished": 0,
                "events_attended": 0,
                "items_bought": 0,
                "comments": 0,
            },
        ),
        patch(
            "lanonna_api.domain.account.storage_usage_for_owner_babies",
            return_value={"used_bytes": 1000, "quota_bytes": 16106127360},
        ),
    ):
        data = build_account_extensions("uid")

    assert data["storage_usage"]["used_bytes"] == 1000
