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
| **API** | `GET …/invitations` returns `can_resend_email`, computed in SQL from server truth: pending invite, no `email_sent_at`, and delivery `failed` — or `pending` for longer than `INVITE_EMAIL_STUCK_MINUTES` (15, the worker's `_CLAIM_STALE_MINUTES` reclaim window, so a crashed send becomes resendable). A parity test keeps the two constants equal. |
| **Mobile model** | `InvitationRow.canResendEmail` reads the server flag; there is no client copy of the rule (`invite_email_delivery.dart` deleted). `emailDeliveryInFlight` = pending send the server will not let you resend yet. |
| **Manage followers** | Loads are serialized (a reload requested mid-load runs once after it). While any row is in flight, a one-shot 2 s timer reloads; at most 30 polls per in-flight window, then it waits for the next manual refresh. Resend always reloads afterwards, including on 409 `invite_already_delivered`. |
| **Copy** | `errorInviteAlreadyDelivered` gives the next step (revoke and re-invite). |

## Tests

- `test_invite_resend_state_postgres.py`: `can_resend_email` for failed, in-flight, stuck, sent and revoked invites.
- `test_invite_email_stuck_parity.py`: API stuck window equals the worker reclaim window.
- `test_list_envelopes.py`: router passes the server flag through.
- `invitation_row_test.dart`: flag from JSON; in-flight detection.
- `followers_screen_test.dart`: polling updates row to sent; polling stops after its window; stuck send shows Resend and stops polling; 409 reloads.

## Compatibility

An older API without `can_resend_email` reads as `false`, so the app never offers a resend the server would reject.
