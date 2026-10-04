#!/usr/bin/env python3
"""Maestro E2E fixtures in Cloud SQL (+ Firebase email verification).

Subcommands:
  all          — owner + follower + dual_baby + domain seeds (default for run-maestro)
  owner        — smoke owner onboarded with primary baby
  follower     — follower user + membership on owner's primary baby
  dual_baby    — second baby on owner (baby switcher tests)
  seeds        — event, registry_item, photo_ready, pending_invite on primary baby
  qa           — dedicated QA owner/follower + enrichment for manual feature validation

Env:
  SMOKE_TEST_EMAIL / SMOKE_TEST_PASSWORD — owner
  FOLLOWER_TEST_EMAIL / FOLLOWER_TEST_PASSWORD — follower (default lanonna.dev.follower@test.com)
  MAESTRO_FIXTURES_OUT — optional path to write invite token + ids as shell-friendly KEY=value lines

Requires Cloud SQL proxy (see clear_dev_test_data.py).
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import secrets
import sys
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import psycopg
from psycopg.rows import dict_row

def _repo_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _firebase_api_key() -> str:
    path = os.path.join(_repo_root(), "apps", "mobile", "lib", "firebase_options.dart")
    text = open(path, encoding="utf-8").read()
    match = re.search(r"apiKey: '([^']+)'", text)
    if not match:
        raise SystemExit("Could not read Firebase apiKey from firebase_options.dart")
    return match.group(1)


def _sign_in(email: str, password: str) -> tuple[str, str]:
    import urllib.request

    api_key = _firebase_api_key()
    body = json.dumps(
        {"email": email, "password": password, "returnSecureToken": True}
    ).encode()
    req = urllib.request.Request(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.load(resp)
    return payload["idToken"], payload["localId"]


def _jwt_email_verified(id_token: str) -> bool:
    segment = id_token.split(".")[1]
    padding = "=" * (-len(segment) % 4)
    claims = json.loads(base64.urlsafe_b64decode(segment + padding))
    return bool(claims.get("email_verified"))


def _ensure_firebase_user(email: str, password: str) -> str:
    """Return firebase uid; create the dev user if missing."""
    try:
        _, uid = _sign_in(email, password)
        return uid
    except Exception:
        pass
    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth
    except ImportError:
        raise SystemExit(
            f"Cannot sign in or create Firebase user {email}; install firebase-admin."
        ) from None
    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={"projectId": "lanonna-dev"})
    try:
        user = firebase_auth.get_user_by_email(email)
        firebase_auth.update_user(user.uid, password=password, email_verified=True)
        return user.uid
    except firebase_auth.UserNotFoundError:
        user = firebase_auth.create_user(
            email=email,
            password=password,
            email_verified=True,
        )
        return user.uid


def _sync_firebase_password(email: str, password: str) -> None:
    """Always align Firebase password with env (sign-in may succeed with an old password)."""
    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth
    except ImportError:
        return
    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={"projectId": "lanonna-dev"})
    user = firebase_auth.get_user_by_email(email)
    firebase_auth.update_user(user.uid, password=password, email_verified=True)


def _ensure_firebase_email_verified(uid: str) -> None:
    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth
    except ImportError:
        print(
            "firebase-admin not installed; skipping Firebase email_verified update",
            file=sys.stderr,
        )
        return

    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={"projectId": "lanonna-dev"})
    user = firebase_auth.get_user(uid)
    if user.email_verified:
        return
    firebase_auth.update_user(uid, email_verified=True)
    print("Marked Firebase email verified.")


def connect() -> psycopg.Connection:
    host = os.environ.get("DB_HOST", "127.0.0.1")
    port = int(os.environ.get("DB_PORT", "5433"))
    user = os.environ.get("DB_USER", "lanonna_app")
    dbname = os.environ.get("DB_NAME", "lanonna")
    password = os.environ.get("DB_PASSWORD") or os.environ.get("PGPASSWORD")
    if not password:
        raise SystemExit(
            "Set DB_PASSWORD or PGPASSWORD (e.g. gcloud secrets versions access "
            "latest --secret=db-lanonna-app-password --project=lanonna-dev)."
        )
    return psycopg.connect(
        host=host,
        port=port,
        user=user,
        dbname=dbname,
        password=password,
        row_factory=dict_row,
    )


def _hash_invite_token(token: str) -> str:
    return hashlib.sha256(token.strip().encode("utf-8")).hexdigest()


def _primary_owner_baby(conn: psycopg.Connection, owner_uid: str) -> dict[str, Any] | None:
    row = conn.execute(
        """
        SELECT b.id, b.name
        FROM baby_memberships m
        JOIN baby_profiles b ON b.id = m.baby_profile_id
        WHERE m.firebase_uid = %s
          AND m.role = 'owner'
          AND m.removed_at IS NULL
          AND b.deleted_at IS NULL
        ORDER BY b.created_at ASC
        LIMIT 1
        """,
        (owner_uid,),
    ).fetchone()
    return dict(row) if row else None


def provision_owner(conn: psycopg.Connection, uid: str, email: str) -> uuid.UUID:
    conn.execute(
        """
        INSERT INTO app_users (firebase_uid, email, display_name)
        VALUES (%s, %s, %s)
        ON CONFLICT (firebase_uid) DO UPDATE
          SET email = EXCLUDED.email,
              display_name = COALESCE(
                NULLIF(TRIM(app_users.display_name), ''),
                EXCLUDED.display_name
              ),
              updated_at = now()
        """,
        (uid, email, "Maestro Smoke"),
    )
    baby = _primary_owner_baby(conn, uid)
    if baby is None:
        baby_id = uuid.uuid4()
        conn.execute(
            """
            INSERT INTO baby_profiles (
                id, name, gender, expected_birth_date,
                actual_birth_date, lifecycle_status
            )
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (baby_id, "Maestro Baby", "male", None, None, "expecting"),
        )
        conn.execute(
            """
            INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role)
            VALUES (%s, %s, 'owner')
            """,
            (baby_id, uid),
        )
        print("Created owner baby: Maestro Baby")
    else:
        baby_id = uuid.UUID(str(baby["id"]))

    conn.execute(
        """
        UPDATE app_users
        SET owner_onboarding_completed_at = COALESCE(owner_onboarding_completed_at, now()),
            updated_at = now()
        WHERE firebase_uid = %s
        """,
        (uid,),
    )
    conn.commit()
    print(f"Owner provisioned ({email}).")
    return baby_id


def provision_follower(
    conn: psycopg.Connection,
    follower_uid: str,
    follower_email: str,
    owner_uid: str,
    baby_id: uuid.UUID,
) -> None:
    conn.execute(
        """
        INSERT INTO app_users (firebase_uid, email, display_name)
        VALUES (%s, %s, %s)
        ON CONFLICT (firebase_uid) DO UPDATE
          SET email = EXCLUDED.email,
              display_name = COALESCE(
                NULLIF(TRIM(app_users.display_name), ''),
                EXCLUDED.display_name
              ),
              updated_at = now()
        """,
        (follower_uid, follower_email, "Maestro Follower"),
    )
    conn.execute(
        """
        INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role, relationship_label)
        VALUES (%s, %s, 'follower', 'Friend')
        ON CONFLICT (baby_profile_id, firebase_uid) DO UPDATE
          SET removed_at = NULL,
              role = 'follower',
              updated_at = now()
        """,
        (baby_id, follower_uid),
    )
    conn.execute(
        """
        UPDATE app_users
        SET owner_onboarding_completed_at = COALESCE(owner_onboarding_completed_at, now()),
            updated_at = now()
        WHERE firebase_uid = %s
        """,
        (follower_uid,),
    )
    conn.commit()
    print(f"Follower provisioned ({follower_email}) on baby {baby_id}.")


def provision_dual_baby(conn: psycopg.Connection, owner_uid: str) -> uuid.UUID:
    row = conn.execute(
        """
        SELECT b.id FROM baby_profiles b
        JOIN baby_memberships m ON m.baby_profile_id = b.id
        WHERE m.firebase_uid = %s AND m.role = 'owner' AND b.name = 'Maestro Baby Two'
          AND m.removed_at IS NULL AND b.deleted_at IS NULL
        LIMIT 1
        """,
        (owner_uid,),
    ).fetchone()
    if row:
        print("Second baby already exists.")
        return uuid.UUID(str(row["id"]))

    baby_id = uuid.uuid4()
    conn.execute(
        """
        INSERT INTO baby_profiles (
            id, name, gender, expected_birth_date,
            actual_birth_date, lifecycle_status
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (baby_id, "Maestro Baby Two", "female", None, None, "expecting"),
    )
    conn.execute(
        """
        INSERT INTO baby_memberships (baby_profile_id, firebase_uid, role)
        VALUES (%s, %s, 'owner')
        """,
        (baby_id, owner_uid),
    )
    conn.commit()
    print("Created second owner baby: Maestro Baby Two")
    return baby_id


def cleanup_baby_gallery(conn: psycopg.Connection, baby_id: uuid.UUID) -> int:
    """Remove all gallery rows for a baby (QA re-seed; cascades comments/squishes/tags)."""
    rows = conn.execute(
        """
        DELETE FROM photos
        WHERE baby_profile_id = %s
        RETURNING id
        """,
        (baby_id,),
    ).fetchall()
    conn.commit()
    count = len(rows)
    if count:
        print(f"Removed {count} gallery photo row(s) for baby {baby_id}.")
    return count


def provision_domain_seeds(
    conn: psycopg.Connection,
    owner_uid: str,
    baby_id: uuid.UUID,
    *,
    include_sql_photo: bool = True,
) -> dict[str, str]:
    out: dict[str, str] = {"baby_profile_id": str(baby_id)}

    # Calendar event (future)
    event_row = conn.execute(
        """
        SELECT id FROM events
        WHERE baby_profile_id = %s AND title = 'Maestro Test Event'
        LIMIT 1
        """,
        (baby_id,),
    ).fetchone()
    if event_row:
        event_id = event_row["id"]
    else:
        event_id = uuid.uuid4()
        starts = datetime.now(timezone.utc) + timedelta(days=30)
        conn.execute(
            """
            INSERT INTO events (
                id, baby_profile_id, created_by_firebase_uid,
                title, starts_at
            )
            VALUES (%s, %s, %s, %s, %s)
            """,
            (event_id, baby_id, owner_uid, "Maestro Test Event", starts),
        )
        print("Seeded calendar event.")
    out["event_id"] = str(event_id)

    # Registry item
    reg_row = conn.execute(
        """
        SELECT id FROM registry_items
        WHERE baby_profile_id = %s AND name = 'Maestro Test Gift'
        LIMIT 1
        """,
        (baby_id,),
    ).fetchone()
    if reg_row:
        registry_id = reg_row["id"]
    else:
        registry_id = uuid.uuid4()
        conn.execute(
            """
            INSERT INTO registry_items (
                id, baby_profile_id, created_by_firebase_uid, name, priority
            )
            VALUES (%s, %s, %s, %s, %s)
            """,
            (registry_id, baby_id, owner_uid, "Maestro Test Gift", 3),
        )
        print("Seeded registry item.")
    out["registry_item_id"] = str(registry_id)

    if include_sql_photo:
        photo_row = conn.execute(
            """
            SELECT id FROM photos
            WHERE baby_profile_id = %s AND caption = 'Maestro E2E Photo'
            LIMIT 1
            """,
            (baby_id,),
        ).fetchone()
        if photo_row:
            photo_id = photo_row["id"]
        else:
            photo_id = uuid.uuid4()
            display_path = f"display/maestro/{photo_id}.jpg"
            thumb_path = f"thumbnails/maestro/{photo_id}.jpg"
            conn.execute(
                """
                INSERT INTO photos (
                    id, baby_profile_id, uploader_firebase_uid,
                    status, display_path, thumb_path,
                    content_type, byte_length, caption
                )
                VALUES (%s, %s, %s, 'ready', %s, %s, 'image/jpeg', 1024, 'Maestro E2E Photo')
                """,
                (photo_id, baby_id, owner_uid, display_path, thumb_path),
            )
            print("Seeded ready photo.")
        out["photo_id"] = str(photo_id)

    # Pending invite for follower email (new token each seeds run if missing)
    follower_email = os.environ.get(
        "FOLLOWER_TEST_EMAIL", "lanonna.dev.follower@test.com"
    )
    invite_token = os.environ.get("MAESTRO_INVITE_TOKEN") or secrets.token_urlsafe(32)
    conn.execute(
        """
        DELETE FROM invitations
        WHERE baby_profile_id = %s
          AND lower(invitee_email) = lower(%s)
          AND status = 'pending'
        """,
        (baby_id, follower_email),
    )
    invite_id = uuid.uuid4()
    expires = datetime.now(timezone.utc) + timedelta(days=14)
    conn.execute(
        """
        INSERT INTO invitations (
            id, baby_profile_id, inviter_firebase_uid,
            invitee_email, role, relationship_label,
            token_hash, expires_at, status
        )
        VALUES (%s, %s, %s, %s, 'follower', 'Friend', %s, %s, 'pending')
        """,
        (
            invite_id,
            baby_id,
            owner_uid,
            follower_email,
            _hash_invite_token(invite_token),
            expires,
        ),
    )
    out["invitation_id"] = str(invite_id)
    out["invite_token"] = invite_token
    print("Seeded pending invitation.")

    conn.commit()
    return out


def provision_qa_enrichment(
    conn: psycopg.Connection,
    owner_uid: str,
    follower_uid: str | None,
    baby_id: uuid.UUID,
    event_id: uuid.UUID,
    registry_needed_id: uuid.UUID,
) -> None:
    """Extra SQL fixtures for manual feature validation (non-Maestro QA accounts)."""
    due = datetime.now(timezone.utc).date() + timedelta(days=120)
    conn.execute(
        """
        UPDATE baby_profiles
        SET name = 'Parker',
            gender = 'male',
            expected_birth_date = %s,
            lifecycle_status = 'expecting',
            registry_shipping_address = '123 QA Lane, Austin, TX 78701',
            updated_at = now()
        WHERE id = %s
        """,
        (due, baby_id),
    )
    conn.execute(
        """
        UPDATE app_users
        SET display_name = 'Sarah QA', updated_at = now()
        WHERE firebase_uid = %s
        """,
        (owner_uid,),
    )
    if follower_uid:
        conn.execute(
            """
            UPDATE app_users
            SET display_name = 'Alex QA', updated_at = now()
            WHERE firebase_uid = %s
            """,
            (follower_uid,),
        )

    for gender, name in (("male", "James"), ("female", "Emma")):
        row = conn.execute(
            """
            SELECT id FROM name_suggestions
            WHERE baby_profile_id = %s AND suggested_name = %s
            LIMIT 1
            """,
            (baby_id, name),
        ).fetchone()
        if not row:
            conn.execute(
                """
                INSERT INTO name_suggestions (
                    id, baby_profile_id, suggested_by_firebase_uid,
                    suggested_name, gender
                )
                VALUES (%s, %s, %s, %s, %s)
                """,
                (uuid.uuid4(), baby_id, owner_uid, name, gender),
            )

    purchased_row = conn.execute(
        """
        SELECT id FROM registry_items
        WHERE baby_profile_id = %s AND name = 'QA Purchased Stroller'
        LIMIT 1
        """,
        (baby_id,),
    ).fetchone()
    if purchased_row:
        purchased_id = purchased_row["id"]
    else:
        purchased_id = uuid.uuid4()
        conn.execute(
            """
            INSERT INTO registry_items (
                id, baby_profile_id, created_by_firebase_uid,
                name, description, priority
            )
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                purchased_id,
                baby_id,
                owner_uid,
                "QA Purchased Stroller",
                "Already claimed for registry Purchased tab",
                4,
            ),
        )
    if follower_uid:
        conn.execute(
            """
            INSERT INTO registry_purchases (id, registry_item_id, purchased_by_firebase_uid)
            VALUES (%s, %s, %s)
            ON CONFLICT (registry_item_id) DO NOTHING
            """,
            (uuid.uuid4(), purchased_id, follower_uid),
        )
        conn.execute(
            """
            INSERT INTO event_rsvps (event_id, firebase_uid, status)
            VALUES (%s, %s, 'going')
            ON CONFLICT (event_id, firebase_uid) DO UPDATE
              SET status = EXCLUDED.status, updated_at = now()
            """,
            (event_id, follower_uid),
        )
        conn.execute(
            """
            INSERT INTO votes (
                id, baby_profile_id, firebase_uid, vote_type,
                gender_value, is_anonymous
            )
            VALUES (%s, %s, %s, 'gender', 'male', false)
            ON CONFLICT (baby_profile_id, firebase_uid, vote_type) DO UPDATE
              SET gender_value = EXCLUDED.gender_value, updated_at = now()
            """,
            (uuid.uuid4(), baby_id, follower_uid),
        )

    conn.execute(
        """
        UPDATE registry_items
        SET description = 'Still needed — follower can claim'
        WHERE id = %s
        """,
        (registry_needed_id,),
    )

    event_comment = conn.execute(
        """
        SELECT id FROM event_comments
        WHERE event_id = %s AND body = 'QA event comment'
        LIMIT 1
        """,
        (event_id,),
    ).fetchone()
    if not event_comment:
        conn.execute(
            """
            INSERT INTO event_comments (
                id, event_id, author_firebase_uid, body
            )
            VALUES (%s, %s, %s, %s)
            """,
            (uuid.uuid4(), event_id, owner_uid, "QA event comment"),
        )

    conn.execute(
        """
        UPDATE baby_profiles
        SET name = 'Jordan', updated_at = now()
        WHERE id IN (
            SELECT b.id FROM baby_profiles b
            JOIN baby_memberships m ON m.baby_profile_id = b.id
            WHERE m.firebase_uid = %s AND m.role = 'owner'
              AND b.name = 'Maestro Baby Two' AND b.deleted_at IS NULL
        )
        """,
        (owner_uid,),
    )
    conn.commit()
    print("QA enrichment applied (profile, fun, registry, RSVP, comments).")


def _firebase_user(email: str, password: str) -> tuple[str, str]:
    id_token, uid = _sign_in(email, password)
    if not _jwt_email_verified(id_token):
        _ensure_firebase_email_verified(uid)
    return id_token, uid


def _write_out(values: dict[str, str]) -> None:
    path = os.environ.get("MAESTRO_FIXTURES_OUT")
    if not path:
        return
    with open(path, "w", encoding="utf-8") as f:
        for k, v in values.items():
            f.write(f"{k}={v}\n")
    print(f"Wrote fixture ids to {path}")


def cmd_owner(_: argparse.Namespace) -> None:
    email = os.environ.get("SMOKE_TEST_EMAIL", "lanonna.dev.smoke@test.com")
    password = os.environ.get("SMOKE_TEST_PASSWORD")
    if not password:
        raise SystemExit("Set SMOKE_TEST_PASSWORD.")
    _, uid = _firebase_user(email, password)
    with connect() as conn:
        provision_owner(conn, uid, email)


def cmd_follower(_: argparse.Namespace) -> None:
    owner_email = os.environ.get("SMOKE_TEST_EMAIL", "lanonna.dev.smoke@test.com")
    owner_password = os.environ.get("SMOKE_TEST_PASSWORD")
    follower_email = os.environ.get(
        "FOLLOWER_TEST_EMAIL", "lanonna.dev.follower@test.com"
    )
    follower_password = os.environ.get("FOLLOWER_TEST_PASSWORD") or owner_password
    if not owner_password or not follower_password:
        raise SystemExit("Set SMOKE_TEST_PASSWORD and FOLLOWER_TEST_PASSWORD.")

    _, owner_uid = _firebase_user(owner_email, owner_password)
    _, follower_uid = _firebase_user(follower_email, follower_password)

    with connect() as conn:
        baby_id = provision_owner(conn, owner_uid, owner_email)
        provision_follower(conn, follower_uid, follower_email, owner_uid, baby_id)


def cmd_dual_baby(_: argparse.Namespace) -> None:
    email = os.environ.get("SMOKE_TEST_EMAIL", "lanonna.dev.smoke@test.com")
    password = os.environ.get("SMOKE_TEST_PASSWORD")
    if not password:
        raise SystemExit("Set SMOKE_TEST_PASSWORD.")
    _, uid = _firebase_user(email, password)
    with connect() as conn:
        provision_owner(conn, uid, email)
        provision_dual_baby(conn, uid)


def cmd_seeds(_: argparse.Namespace) -> None:
    email = os.environ.get("SMOKE_TEST_EMAIL", "lanonna.dev.smoke@test.com")
    password = os.environ.get("SMOKE_TEST_PASSWORD")
    if not password:
        raise SystemExit("Set SMOKE_TEST_PASSWORD.")
    _, uid = _firebase_user(email, password)
    with connect() as conn:
        baby_id = provision_owner(conn, uid, email)
        out = provision_domain_seeds(conn, uid, baby_id)
    _write_out(out)
    for k, v in out.items():
        print(f"{k}={v}")


def cmd_onboarding_reset(_: argparse.Namespace) -> None:
    """Reset a dedicated Firebase user for owner onboarding UI tests."""
    email = os.environ.get("ONBOARDING_TEST_EMAIL", "lanonna.dev.onboard@test.com")
    password = os.environ.get("ONBOARDING_TEST_PASSWORD") or os.environ.get(
        "SMOKE_TEST_PASSWORD"
    )
    if not password:
        raise SystemExit("Set ONBOARDING_TEST_PASSWORD or SMOKE_TEST_PASSWORD.")
    _, uid = _firebase_user(email, password)
    with connect() as conn:
        conn.execute(
            """
            UPDATE app_users
            SET owner_onboarding_completed_at = NULL,
                display_name = NULL,
                updated_at = now()
            WHERE firebase_uid = %s
            """,
            (uid,),
        )
        baby_ids = conn.execute(
            """
            SELECT b.id FROM baby_profiles b
            JOIN baby_memberships m ON m.baby_profile_id = b.id
            WHERE m.firebase_uid = %s AND m.role = 'owner' AND m.removed_at IS NULL
            """,
            (uid,),
        ).fetchall()
        for row in baby_ids:
            bid = row["id"]
            conn.execute(
                "DELETE FROM invitations WHERE baby_profile_id = %s", (bid,)
            )
            conn.execute("DELETE FROM photos WHERE baby_profile_id = %s", (bid,))
            conn.execute("DELETE FROM events WHERE baby_profile_id = %s", (bid,))
            conn.execute("DELETE FROM registry_items WHERE baby_profile_id = %s", (bid,))
            conn.execute(
                "DELETE FROM baby_memberships WHERE baby_profile_id = %s", (bid,)
            )
            conn.execute("DELETE FROM baby_profiles WHERE id = %s", (bid,))
        conn.commit()
    print(f"Onboarding reset for {email} ({uid}).")


def cmd_all(_: argparse.Namespace) -> None:
    email = os.environ.get("SMOKE_TEST_EMAIL", "lanonna.dev.smoke@test.com")
    password = os.environ.get("SMOKE_TEST_PASSWORD")
    follower_email = os.environ.get(
        "FOLLOWER_TEST_EMAIL", "lanonna.dev.follower@test.com"
    )
    follower_password = os.environ.get("FOLLOWER_TEST_PASSWORD") or password
    if not password:
        raise SystemExit("Set SMOKE_TEST_PASSWORD.")

    _, owner_uid = _firebase_user(email, password)
    follower_uid = None
    if follower_password:
        try:
            follower_uid = _ensure_firebase_user(follower_email, follower_password)
            _ensure_firebase_email_verified(follower_uid)
        except Exception as exc:
            print(f"Warning: follower provisioning failed ({exc}); skipping follower.", file=sys.stderr)

    with connect() as conn:
        baby_id = provision_owner(conn, owner_uid, email)
        second_baby_id = provision_dual_baby(conn, owner_uid)
        if follower_uid:
            provision_follower(conn, follower_uid, follower_email, owner_uid, baby_id)
        out = provision_domain_seeds(conn, owner_uid, baby_id)
        out["second_baby_profile_id"] = str(second_baby_id)
    _write_out(out)
    print("Maestro fixtures (all) complete.")


def cmd_qa(_: argparse.Namespace) -> None:
    """Dedicated owner + follower accounts for manual feature validation."""
    owner_email = os.environ.get(
        "QA_OWNER_EMAIL", "lanonna.dev.qa.owner@test.com"
    )
    follower_email = os.environ.get(
        "QA_FOLLOWER_EMAIL", "lanonna.dev.qa.follower@test.com"
    )
    password = os.environ.get("QA_TEST_PASSWORD") or os.environ.get(
        "SMOKE_TEST_PASSWORD"
    )
    if not password:
        raise SystemExit("Set QA_TEST_PASSWORD or SMOKE_TEST_PASSWORD.")

    owner_uid = _ensure_firebase_user(owner_email, password)
    _ensure_firebase_email_verified(owner_uid)
    follower_uid = _ensure_firebase_user(follower_email, password)
    _ensure_firebase_email_verified(follower_uid)
    _sync_firebase_password(owner_email, password)
    _sync_firebase_password(follower_email, password)

    with connect() as conn:
        baby_id = provision_owner(conn, owner_uid, owner_email)
        second_baby_id = provision_dual_baby(conn, owner_uid)
        provision_follower(
            conn, follower_uid, follower_email, owner_uid, baby_id
        )
        cleanup_baby_gallery(conn, baby_id)
        out = provision_domain_seeds(
            conn, owner_uid, baby_id, include_sql_photo=False
        )
        provision_qa_enrichment(
            conn,
            owner_uid,
            follower_uid,
            baby_id,
            uuid.UUID(out["event_id"]),
            uuid.UUID(out["registry_item_id"]),
        )
        out["second_baby_profile_id"] = str(second_baby_id)
        out["qa_owner_email"] = owner_email
        out["qa_follower_email"] = follower_email
    _write_out(out)
    print("QA validation accounts ready.")
    print(f"  Owner:    {owner_email}")
    print(f"  Follower: {follower_email}")
    print("  Primary baby: Parker (expecting); second baby: Jordan (switcher).")
    print("  Gallery: run scripts/seed_qa_gallery_photo.sh after provision.")


def cmd_qa_cleanup_gallery(_: argparse.Namespace) -> None:
    baby_id_raw = os.environ.get("QA_BABY_PROFILE_ID")
    if not baby_id_raw:
        raise SystemExit("Set QA_BABY_PROFILE_ID (from maestro/.qa-fixtures.env).")
    baby_id = uuid.UUID(baby_id_raw)
    with connect() as conn:
        cleanup_baby_gallery(conn, baby_id)


def main() -> None:
    parser = argparse.ArgumentParser(description="Provision Maestro E2E SQL fixtures")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser(
        "qa",
        help="QA owner + follower with enriched fixtures (manual validation)",
    )
    sub.add_parser(
        "qa_cleanup_gallery",
        help="Delete all photos for QA baby (QA_BABY_PROFILE_ID)",
    )
    sub.add_parser("all", help="Owner + dual baby + follower + domain seeds")
    sub.add_parser("owner", help="Owner smoke user only")
    sub.add_parser("follower", help="Owner + follower membership")
    sub.add_parser("dual_baby", help="Second baby on owner")
    sub.add_parser("seeds", help="Event, registry, photo, invite on primary baby")
    sub.add_parser(
        "onboarding_reset",
        help="Reset ONBOARDING_TEST_EMAIL for fresh owner onboarding UI",
    )
    args = parser.parse_args()
    handlers = {
        "qa_cleanup_gallery": cmd_qa_cleanup_gallery,
        "qa": cmd_qa,
        "all": cmd_all,
        "owner": cmd_owner,
        "follower": cmd_follower,
        "dual_baby": cmd_dual_baby,
        "seeds": cmd_seeds,
        "onboarding_reset": cmd_onboarding_reset,
    }
    handlers[args.cmd](args)


if __name__ == "__main__":
    main()
