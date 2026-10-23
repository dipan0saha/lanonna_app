"""Popular Dates and the home top guess skip votes outside the window (#413)."""

from __future__ import annotations

import uuid
from datetime import date

import pytest

from lanonna_api.db import get_connection
from lanonna_api.domain.birthdate_vote_window import birthdate_vote_shown_window
from lanonna_api.repositories.fun import birthdate_vote_histogram
from lanonna_api.repositories.home_counts import home_summary_counts
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_DUE = date(2027, 1, 15)


def _baby_with_votes(votes: dict[str, date]) -> uuid.UUID:
    owner = "owner-uid"
    resolve_app_user(owner, "owner@example.test")
    baby_id = uuid.uuid4()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO baby_profiles (
                id, name, lifecycle_status, expected_birth_date, created_by_firebase_uid
            )
            VALUES (%s, 'Parker', 'expecting', %s, %s)
            """,
            (baby_id, _DUE, owner),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, joined_via)
            VALUES (%s, %s, 'owner', 'created')
            """,
            (baby_id, owner),
        )
    for uid, predicted in votes.items():
        if uid != owner:
            resolve_app_user(uid, f"{uid}@example.test")
            with get_connection() as conn:
                conn.execute(
                    """
                    INSERT INTO baby_memberships (
                        baby_profile_id, firebase_uid, role, joined_via
                    )
                    VALUES (%s, %s, 'follower', 'invite')
                    """,
                    (baby_id, uid),
                )
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO votes (
                    baby_profile_id, firebase_uid, vote_type, predicted_birth_date
                )
                VALUES (%s, %s, 'birthdate', %s)
                """,
                (baby_id, uid, predicted),
            )
    return baby_id


def test_out_of_window_votes_never_count():
    # The most-guessed date is out of range, so it must not win the top guess.
    baby_id = _baby_with_votes(
        {
            "owner-uid": date(2026, 12, 20),
            "follower-a": date(2099, 12, 31),
            "follower-b": date(2099, 12, 31),
            "follower-c": date(2027, 1, 10),
            "follower-d": date(2020, 1, 1),
        }
    )
    window = birthdate_vote_shown_window(_DUE, today=date(2026, 10, 23))

    histogram = birthdate_vote_histogram(baby_id, window)
    assert [(r["predicted_birth_date"], r["count"]) for r in histogram] == [
        (date(2026, 12, 20), 1),
        (date(2027, 1, 10), 1),
    ]
    counts = home_summary_counts(baby_id, birthdate_window=window)
    assert counts["top_birthdate_guess"] == date(2026, 12, 20)


def test_guess_that_is_now_in_the_past_still_counts():
    baby_id = _baby_with_votes({"owner-uid": date(2026, 12, 20)})
    # Weeks later: the guessed day has passed, the baby is still expected.
    window = birthdate_vote_shown_window(_DUE, today=date(2027, 1, 10))
    assert [r["predicted_birth_date"] for r in birthdate_vote_histogram(baby_id, window)] == [
        date(2026, 12, 20)
    ]
