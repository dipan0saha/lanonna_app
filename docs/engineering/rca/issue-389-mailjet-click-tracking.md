# RCA: Issue #389 — Mailjet click tracking embeds invite tokens in third-party URLs

| Field | Value |
|-------|--------|
| **Status** | Fixed (worker Mailjet send layer disables per-message tracking) |
| **Date** | 2026-10-23 |
| **Case** | INV-008 (pre-prod test plan, P1 privacy/hardening) |

## Summary

Family invite emails delivered through Mailjet rewrote every link—including the plain-text “copy this link” fallback—to Mailjet click-tracking URLs (`*.mjt.lu/lnk/...`). The tracker URL embedded a base64 encoding of the full invite URL, so the single-use invite token (bearer credential for preview/accept) was exposed to Mailjet on each click. Hrefs no longer matched visible link text, adding an extra redirect before App Links and hurting deliverability signals.

## Root cause

`services/worker/src/lanonna_worker/invite_email.py` built Mailjet v3.1 `POST /send` payloads with only `From`, `To`, `Subject`, `HTMLPart`, and `TextPart`. No per-message `TrackClicks` / `TrackOpens` fields were set, and the repository had no shared Mailjet helper. Mailjet account defaults (click tracking enabled) therefore applied to all transactional product mail.

Only **invite** email is sent via Mailjet today; future transactional sends (e.g. export-ready notifications) were at risk of the same default unless centralized.

## Fix

- Added `services/worker/src/lanonna_worker/mailjet_send.py`: shared `build_send_payload()` applies `TrackClicks: disabled` and `TrackOpens: disabled` on every message before send.
- `invite_email.py` uses this layer for all Mailjet traffic.
- Worker tests assert tracking fields on the JSON payload (`test_mailjet_send.py`, `test_invite_email.py`).

Operational note: disabling tracking in the API payload is authoritative for sends from this code path. Mailjet sender-level defaults can remain for any non-worker traffic, but product transactional mail should always go through `mailjet_send`.

## Firebase Auth verification and password-reset email (out of scope for Mailjet)

Email verification and password reset are **not** sent through Mailjet. The mobile app calls Firebase Auth; Google delivers mail from Identity Toolkit templates synced from `packages/firebase-auth-email-templates` (`scripts/sync-firebase-auth-templates.sh`). Action links use Firebase Hosting (`https://{project}.firebaseapp.com/__/auth/action?...`) with OOB codes, not Mailjet `mjt.lu` wrappers.

La Nonna does not configure Mailjet-style click rewriting on those messages. Google’s own email infrastructure may still log delivery and link usage under the Firebase/Google Cloud terms—disclose Firebase as the processor for auth mail in `docs/legal/data-inventory.md`, not Mailjet click tracking.

## Verification

1. Deploy worker to dev; send a follower and co-owner invite.
2. Inspect received message HTML and text: `href` on “Accept invitation” and fallback link must be `https://{project}.firebaseapp.com/invite?token=...` (or encoded token), not `mjt.lu`.
3. Tap link on Android: App Link handoff should work without an intermediate Mailjet redirect.

## Related

- Issue #389
- `docs/legal/data-inventory.md` (Mailjet row, §3)
- `packages/email-templates/README.md` (product mail vs Firebase auth mail)
