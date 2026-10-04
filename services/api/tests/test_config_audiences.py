from lanonna_api.config import Settings


def test_firebase_audience_allowlist_defaults_to_project_id():
    s = Settings(gcp_project_id="lanonna-dev", firebase_audiences="")
    assert s.firebase_audience_allowlist() == frozenset({"lanonna-dev"})


def test_firebase_audience_allowlist_parses_csv():
    s = Settings(
        gcp_project_id="lanonna-dev",
        firebase_audiences="lanonna-dev, lanonna-prod",
    )
    assert s.firebase_audience_allowlist() == frozenset({"lanonna-dev", "lanonna-prod"})
