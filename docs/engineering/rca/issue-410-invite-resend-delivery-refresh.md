# RCA: Manage followers stale row after invite resend (#410)

| Field | Value |
|-------|--------|
| **Issue** | [#410](https://github.com/dipan0saha/lanonna_app/issues/410) |
| **Status** | Fixed |
| **Date** | 2026-10-23 |

## Symptom

After **Resend** on a failed invite, the row correctly shows “Pending — email sending”, but it never updates to “Invite email sent” until the screen is reopened. **Resend** stays visible; a second tap returns **409** `invite_already_delivered` while the row still shows in-flight copy.

## Root cause

Delivery state is **server-owned** (`invitations.email_delivery_status`, `email_sent_at`). The worker sets `sent` asynchronously after Mailjet succeeds (`worker/invite_email.py`).

On the mobile **Manage followers** screen:

1. A successful resend calls `_load()` **once**, immediately after the API returns. That reload almost always wins the race and still sees `email_delivery_status = pending`.
2. `InvitationRow.canResendEmail` treated any undelivered pending invite as resendable, including rows already in the **pending** (in-flight) delivery state, so the UI offered **Resend** during the window where the worker was still sending.
3. On **409** `invite_already_delivered`, `runMutation` returned `false` and the handler exited without `_load()`, so the stale in-flight label persisted.

There is no push/event channel for per-invite delivery; the list must **poll** while any row is in-flight.

## Fix

| Layer | Change |
|-------|--------|
| **Mobile domain** | Shared rules in `invite_email_delivery.dart`: `invitationCanResendEmail` only when `email_delivery_status == failed` (and never delivered); `invitationEmailDeliveryInFlight` for `pending` + no `email_sent_at`. |
| **Manage followers** | After resend success or `invite_already_delivered`, reload the list. While any invite is in-flight, periodic silent reload (same pattern as gallery upload polling). Resend uses explicit `ApiException` handling so 409 still refreshes. |
| **Copy** | Clarify `errorInviteAlreadyDelivered` with a next step (revoke and re-invite). |

API resend contract unchanged; the UI mirrors when resend is allowed.

## Tests

- `invitation_row_test.dart`: resend only for `failed`; not for `pending` in-flight.
- `invite_email_delivery_test.dart`: in-flight detection.
- `followers_screen_test.dart`: polling updates row to sent; 409 triggers reload.

## Compatibility

Older API rows with null `email_delivery_status` are not offered resend unless `failed`; stuck initial sends are picked up by polling without a second resend.
