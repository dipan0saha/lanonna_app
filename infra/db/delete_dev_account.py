#!/usr/bin/env python3
"""Delete a dev / QA account by email through the product delete path.

Runs ``lanonna_api.domain.account_delete.delete_account``: the same single
transaction as ``POST /v1/me/delete-account`` (sole-owned babies hard-deleted,
personal rows purged, tombstone), then the async GCS cleanup publish (the
worker sweep retries it) and the Firebase Auth delete. Use it for an account
you cannot sign in to. Run through ``scripts/delete_dev_account.sh``.

``--dry-run`` lists the baby profiles that would be deleted with the account.
Never run against the Maestro smoke / QA fixture accounts.
"""

from __future__ import annotations

import argparse
import re

from lanonna_api.domain.account_delete import delete_account, delete_account_preview

from clear_dev_test_data import _resolve_user, connect

_PROTECTED_EMAIL_RE = re.compile(
    r"^lanonna\.dev\.(smoke|qa\.(owner|follower))@test\.com$",
    re.IGNORECASE,
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", required=True, help="User email in app_users")
    parser.add_argument("--dry-run", action="store_true", help="Preview only; no changes.")
    args = parser.parse_args()

    email = args.email.strip()
    if _PROTECTED_EMAIL_RE.match(email):
        raise SystemExit(
            "Refusing to delete a protected fixture account. Use a disposable test account."
        )
    with connect() as conn:
        uid = _resolve_user(conn, email, None)["firebase_uid"]

    babies = delete_account_preview(uid)["sole_owned_babies"]
    print(f"Account {uid}: {len(babies)} sole-owned baby profile(s) will be deleted.")
    if args.dry_run:
        print("Dry run: nothing changed.")
        return
    delete_account(uid)
    print("Deleted (tombstoned; storage cleanup queued; Firebase user removed).")


if __name__ == "__main__":
    main()
