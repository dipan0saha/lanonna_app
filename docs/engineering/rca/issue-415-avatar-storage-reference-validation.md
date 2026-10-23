# RCA: Avatar and storage reference validation (#415)

## Summary

`PATCH /v1/profile` and `PATCH /v1/babies/{id}` accepted any string as `avatar_url`: another user's `avatars/…` object path, arbitrary external hosts, and plain `http://` URLs. Stored values were returned through `signed_avatar_url`, which minted a read URL for any path under `avatars/` (or legacy `smoke/`), so a caller could persist a victim's object path and receive a freshly signed URL on the next profile or baby list response. The baby data export (worker) signed the stored baby avatar the same way.

## Threat model

| Attack | Write path | Read path | Confirmed |
|--------|------------|-----------|-----------|
| Cross-account avatar path | `normalize_avatar_for_storage` only checked prefix `avatars/` or `smoke/` | Account, baby list and export signed any stored path | Yes (code); covered by integration tests now |
| External HTTPS tracking pixel | Accepted and stored; signer passed through any `http(s)://` | Co-members' apps load the URL | Yes |
| Plain HTTP | Accepted despite HTTPS-only intent in docstring | Same passthrough | Yes |
| Legacy public GCS URL for another user's object | Normalized to object path without ownership check | Signed like any `avatars/` path | Yes |
| Path tricks (`..`, `//`, `\`, leading `/`) | Not rejected | Signed | Yes |

Event covers, announcement photos and gallery reads use baby-scoped **photo ids** that the API resolves against the baby, not raw paths; integration tests now prove a cross-baby id is rejected (400) or not found (404). Registry `product_url` and calendar `video_call_url` used `normalize_optional_http_url`, which allowed `http://`.

## Root cause

`domain/avatar_urls.py` treated display-bucket paths from the client as trusted. Nothing bound `avatars/users/{firebase_uid}/` or `avatars/babies/{baby_id}/` to the authenticated subject or the row, and read-time signing did not re-check ownership, so any bad row already stored stayed exploitable. The database had no constraint either.

## Fix

| Layer | Change |
|-------|--------|
| `domain/storage_references.py` | One pure parser for every display-bucket reference (bare path or our bucket's GCS URL in either host form; rejects `..`, `.`, empty segments, backslashes, leading `/`; never raises on read). Owned-avatar rule: the object must sit directly under the owner prefix. Prefix helpers are shared with upload minting in `storage.py`. |
| `domain/avatar_urls.py` | `normalize_user_avatar_for_storage` / `normalize_baby_avatar_for_storage` (write: blank → null, otherwise owned path or **400** `invalid_storage_reference`); `signed_user_avatar_url` / `signed_baby_avatar_urls` (read: sign only owned paths, otherwise null). Old unscoped signers deleted. |
| `domain/url_validation.py` | HTTPS only in every environment (no localhost/http exception, so nothing depends on environment detection); host must contain a dot; invalid ports rejected. Mobile `form_validators.dart` matches. |
| Migration `049_owned_avatar_references.sql` | Converts legacy GCS URLs to object paths, nulls every avatar that is not owned by its row, then adds CHECK constraints `app_users_avatar_url_owned` and `baby_profiles_avatar_url_owned`. This also covers the worker export, which signs `baby_profiles.avatar_url`. |
| Mobile OAuth photo | `DisplayPhotoUpload.importProfileAvatar`: downloads the provider photo (https only, timeouts), uploads it through the signed PUT, and saves only the returned path. Any failure returns null, so Complete profile still saves without a photo. |
| Mobile errors | `invalid_storage_reference` maps to "That photo can't be used. Choose a photo again." |

## Tests

- `tests/test_storage_references.py`, `tests/test_avatar_urls.py`, `tests/test_url_validation.py` (unit).
- `tests/integration/test_storage_reference_attacks_postgres.py` (Postgres): cross-account user and baby avatars, URLs, traversal, `display/` and `smoke/` paths, follower writes, cross-baby event cover / announcement photo / gallery ids, http links, legacy unowned rows read back as null, 049 cleanup and constraints.
- Mobile: `display_photo_upload_import_test.dart`, `form_validators_test.dart`.

## Rollout

Apply `049` after the API deploy (the old API could still write unowned values, which the constraint would reject with a 500). Users whose legacy avatar was not owned see initials until they pick a photo again. Existing `http://` registry or calendar links stay readable; editing them requires `https://`.

## References

- GitHub #415
- `services/api/src/lanonna_api/domain/storage_references.py`, `avatar_urls.py`, `url_validation.py`
- `services/api/src/lanonna_api/storage.py` (mint paths)
- `infra/db/migrations/049_owned_avatar_references.sql`
