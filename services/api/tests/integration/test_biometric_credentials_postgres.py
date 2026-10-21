"""Postgres: biometric credentials and single-use sign-in challenges."""

from __future__ import annotations

import uuid

import pytest

from lanonna_api.db import get_connection
from lanonna_api.repositories.biometric_credentials import (
    consume_challenge,
    create_challenge,
    get_live_credential,
    register_credential,
    revoke_all_for_user,
)
from lanonna_api.repositories.users import resolve_app_user

pytestmark = pytest.mark.integration

_PEM = "-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----"
_ALG = "ecdsa_p256_sha256"


def _user(uid: str) -> str:
    resolve_app_user(uid, f"{uid}@test.com")
    return uid


def _register(uid: str, device: str = "device-aaaaaaaaaaaa") -> uuid.UUID:
    return uuid.UUID(register_credential(uid, device, _PEM, _ALG)["id"])


def test_challenge_is_single_use(postgres_database: str):
    cred = _register(_user("bio-single-use"))
    challenge = create_challenge(cred)
    challenge_id = uuid.UUID(challenge["challenge_id"])
    assert consume_challenge(challenge_id, cred) == challenge["nonce"]
    assert consume_challenge(challenge_id, cred) is None


def test_challenge_is_bound_to_its_credential(postgres_database: str):
    uid = _user("bio-bound")
    cred = _register(uid, "device-bbbbbbbbbbbb")
    other = _register(uid, "device-cccccccccccc")
    challenge_id = uuid.UUID(create_challenge(cred)["challenge_id"])
    assert consume_challenge(challenge_id, other) is None
    assert consume_challenge(challenge_id, cred) is not None


def test_expired_challenge_is_rejected_and_removed(postgres_database: str):
    cred = _register(_user("bio-expired"))
    challenge_id = uuid.UUID(create_challenge(cred)["challenge_id"])
    with get_connection() as conn:
        conn.execute(
            "UPDATE biometric_sign_in_challenges SET expires_at = now() - interval '1 second' WHERE id = %s",
            (challenge_id,),
        )
    assert consume_challenge(challenge_id, cred) is None
    with get_connection() as conn:
        left = conn.execute(
            "SELECT count(*) AS n FROM biometric_sign_in_challenges WHERE id = %s",
            (challenge_id,),
        ).fetchone()
    assert left["n"] == 0


def test_new_challenge_replaces_the_previous_one(postgres_database: str):
    cred = _register(_user("bio-replace"))
    first = uuid.UUID(create_challenge(cred)["challenge_id"])
    second = create_challenge(cred)
    assert consume_challenge(first, cred) is None
    assert consume_challenge(uuid.UUID(second["challenge_id"]), cred) == second["nonce"]


def test_reenroll_on_same_install_revokes_only_that_account_key(postgres_database: str):
    a = _user("bio-reenroll-a")
    b = _user("bio-reenroll-b")
    first = _register(a, "device-shared000000")
    other_account = _register(b, "device-shared000000")
    second = _register(a, "device-shared000000")
    assert get_live_credential(first) is None
    assert get_live_credential(second) is not None
    assert get_live_credential(other_account) is not None


def test_revoke_all_and_tombstone_hide_credentials(postgres_database: str):
    uid = _user("bio-revoke-all")
    cred = _register(uid)
    assert revoke_all_for_user(uid) == 1
    assert get_live_credential(cred) is None

    tomb = _user("bio-tombstoned")
    tomb_cred = _register(tomb)
    from lanonna_api.repositories.account_delete import delete_account_rows

    delete_account_rows(tomb)
    assert get_live_credential(tomb_cred) is None
    with get_connection() as conn:
        row = conn.execute(
            "SELECT revoked_at FROM biometric_credentials WHERE id = %s", (tomb_cred,)
        ).fetchone()
    assert row["revoked_at"] is not None
