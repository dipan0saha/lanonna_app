from lanonna_api.middleware.rate_limit import _is_rate_limited_path


def test_rate_limited_paths():
    assert _is_rate_limited_path("/v1/photos/init")
    assert _is_rate_limited_path(
        "/v1/babies/00000000-0000-0000-0000-000000000001/invitations/batch"
    )
    assert not _is_rate_limited_path("/v1/babies/00000000-0000-0000-0000-000000000001")
