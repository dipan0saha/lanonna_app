# RCA: Avatar and storage reference validation (#415)

## Summary

`PATCH /v1/profile` and `PATCH /v1/babies/{id}` accepted any string as `avatar_url`: another user's `avatars/…` object path, arbitrary external hosts, and plain `http://` URLs. Stored values are returned through `signed_avatar_url`, which mints a read URL for any path under `avatars/` (or legacy `smoke/`), so a caller could persist a victim's object path and receive a freshly signed URL on the next profile or baby list response.

## Threat model

| Attack | Write path | Read path | Confirmed |
|--------|------------|-----------|-----------|
| Cross-account avatar path | `normalize_avatar_for_storage` only checks prefix `avatars/` or `smoke/` | `_to_profile_response` / `baby_summaries_from_rows` call `signed_avatar_url` on the stored path | Yes (code); live exfiltration not run in QA |
| External HTTPS tracking pixel | Accepted and stored; `signed_avatar_urls` passes through any `http(s)://` | Co-members' apps load the URL | Yes |
| Plain HTTP | Accepted despite HTTPS-only intent in docstring | Same passthrough | Yes |
| Legacy public GCS URL for another user's object | Normalized to object path without ownership check | Signed like any `avatars/` path | Yes |

Event covers and announcement photos use baby-scoped **photo ids** from the upload flow, not raw paths, so they were not vulnerable the same way. Registry and calendar **product / video links** used `normalize_optional_http_url`, which still allowed `http://` — tightened to HTTPS-only in the same shared URL validator.

## Root cause

`services/api/src/lanonna_api/domain/avatar_urls.py` treated display-bucket paths as trusted from the client. There was no binding between `avatars/users/{firebase_uid}/` or `avatars/babies/{baby_id}/` and the authenticated subject, and read-time signing did not re-check ownership (so stale malicious rows could still be signed until cleaned).

## Fix

| Layer | Change |
|-------|--------|
| `domain/storage_references.py` | Shared parser for display-bucket object paths; owned-avatar normalization; authorize-before-sign for read |
| `domain/avatar_urls.py` | User/baby-specific normalize and sign APIs; no external URL passthrough |
| `domain/url_validation.py` | Require `https` (keep `localhost` http for dev) |
| `domain/errors.py` | `invalid_storage_reference` (422) |
| Routers | Pass `firebase_uid` / `baby_profile_id` into avatar normalize |
| Mobile | OAuth profile photo: download and upload via signed PUT before PATCH (paths only) |

## Dev data

Existing dev rows may still hold external URLs or cross-account paths. They will stop signing on read (null avatar in API) until users re-upload or ops null them out. No migration was run from this change.

## References

- GitHub #415
- `services/api/src/lanonna_api/domain/avatar_urls.py`
- `services/api/src/lanonna_api/storage.py` (mint paths)
