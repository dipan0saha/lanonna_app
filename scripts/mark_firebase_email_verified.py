#!/usr/bin/env python3
"""Mark a Firebase Auth user as email-verified (lanonna-dev manual QA).

Use after email/password sign-up when the inbox cannot receive mail (e.g. @test.com).

Requires firebase-admin and credentials with permission to update users, e.g.:

  gcloud auth application-default login
  # or: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

From repo root (uses infra/db/.venv — run ``pip install -r requirements.txt`` there once):

  infra/db/.venv/bin/python scripts/mark_firebase_email_verified.py abc@test.com
"""

from __future__ import annotations

import argparse
import sys


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Set email_verified=true for a Firebase Auth user by email.",
    )
    parser.add_argument(
        "email",
        help="Account email (user must already exist in Firebase Auth)",
    )
    parser.add_argument(
        "--project",
        default="lanonna-dev",
        help="Firebase project id (default: lanonna-dev)",
    )
    args = parser.parse_args()
    email = args.email.strip()
    if not email:
        print("email is required", file=sys.stderr)
        return 1

    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth
    except ImportError:
        print(
            "Install firebase-admin: python -m pip install firebase-admin",
            file=sys.stderr,
        )
        return 1

    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={"projectId": args.project})

    try:
        user = firebase_auth.get_user_by_email(email)
    except firebase_auth.UserNotFoundError:
        print(f"No Firebase user with email: {email}", file=sys.stderr)
        return 1

    if user.email_verified:
        print(f"Already verified: {email} (uid={user.uid})")
        return 0

    firebase_auth.update_user(user.uid, email_verified=True)
    print(f"Marked email verified: {email} (uid={user.uid})")
    print("In the app: tap Continue on the verify screen (or wait for auto-refresh).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
