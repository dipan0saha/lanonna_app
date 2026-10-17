import uuid
from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from lanonna_api.auth import current_user
from lanonna_api.main import app

client = TestClient(app)
_BABY = uuid.uuid4()


@contextmanager
def _auth_as(uid: str = "user-1"):
    app.dependency_overrides[current_user] = lambda: {
        "uid": uid,
        "email": "u@test.com",
    }
    try:
        yield
    finally:
        app.dependency_overrides.pop(current_user, None)


def test_put_gender_vote_when_born_returns_409():
    with (
        _auth_as(),
        patch(
            "lanonna_api.domain.fun.require_membership",
            return_value={"role": "follower", "lifecycle_status": "born"},
        ),
        patch("lanonna_api.domain.fun.upsert_gender_vote") as upsert,
    ):
        response = client.put(
            f"/v1/babies/{_BABY}/fun/predictions/gender",
            json={"gender": "male"},
        )
    assert response.status_code == 409
    detail = response.json()["detail"]
    assert detail["error"] == "predictions_closed"
    assert detail["message"] == "Predictions closed — baby has arrived"
    upsert.assert_not_called()


def test_put_birthdate_vote_when_born_returns_409():
    with (
        _auth_as(),
        patch(
            "lanonna_api.domain.fun.require_membership",
            return_value={"role": "follower", "lifecycle_status": "born"},
        ),
        patch("lanonna_api.domain.fun.upsert_birthdate_vote") as upsert,
    ):
        response = client.put(
            f"/v1/babies/{_BABY}/fun/predictions/birthdate",
            json={"predicted_birth_date": "2026-10-01"},
        )
    assert response.status_code == 409
    assert response.json()["detail"]["error"] == "predictions_closed"
    upsert.assert_not_called()


def test_get_predictions_reports_closed_and_keeps_tallies():
    with (
        _auth_as(),
        patch(
            "lanonna_api.domain.fun.require_membership",
            return_value={"role": "follower", "lifecycle_status": "born"},
        ),
        patch(
            "lanonna_api.domain.fun.gender_vote_totals",
            return_value={"male": 2, "female": 1},
        ),
        patch(
            "lanonna_api.domain.fun.get_caller_votes",
            return_value={"gender": "male"},
        ),
        patch("lanonna_api.domain.fun.list_gender_voters", return_value=[]),
        patch("lanonna_api.domain.fun.birthdate_vote_histogram", return_value=[]),
    ):
        response = client.get(f"/v1/babies/{_BABY}/fun/predictions")
    assert response.status_code == 200
    body = response.json()
    assert body["predictions_closed"] is True
    assert body["gender_totals"] == {"male": 2, "female": 1}
    assert body["viewer_gender_vote"] == "male"
