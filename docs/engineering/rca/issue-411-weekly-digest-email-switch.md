# RCA: Notification prefs promise weekly email digest (#411)

| Field | Value |
|-------|--------|
| **Issue** | [#411](https://github.com/dipan0saha/lanonna_app/issues/411) |
| **Status** | Fixed |
| **Date** | 2026-10-23 |

## Symptom

Notification preferences show **“Weekly email digest”** and the account summary **“Weekly email summary”**, but the weekly digest job sends **FCM push only** (no Mailjet email, no inbox row). The `email_digest_enabled` switch saves to `app_users` but is **never read** by `process_weekly_notification_digest`. Copy also implied settings were **per baby** (“for Luna”) while `notification_digest` is **per user**.

## Root cause

Product requirements (`docs/product/requirements.md` §7.14): **Weekly** digest is Scheduler → Pub/Sub → worker **summary FCM**; **Daily** is in-app only in v1. Invite email is the only Mailjet sender path (`issue-389-mailjet-click-tracking.md`).

The mobile screen and ARB strings were written as if a weekly **email** existed. The API exposed `email_digest_enabled` on `PATCH /v1/me/notification-preferences` with no consumer.

## Decision

**Do not build a weekly email digest.** Align UI and API with requirements:

- Remove the dead **email digest** switch and stop accepting `email_digest_enabled` on notification-preferences PATCH (DB column left in place; unused).
- Relabel digest summaries: weekly → **push** summary; daily → **in-app** summary (not email).
- Scope copy: notification preferences apply to **your account** across all babies you follow (not “for {babyName}”).

Weekly delivery still requires `notification_digest = weekly` and `push_notifications_enabled` (unchanged worker behavior).

## Fix

| Layer | Change |
|-------|--------|
| **Mobile** | Remove email switch from `notification_preferences_screen.dart`; update ARB intro/frequency titles and digest summary strings. |
| **API** | Drop `email_digest_enabled` from notification-preferences GET/PATCH payload and `update_notification_preferences`. |
| **Tests** | Update preference schema/router tests; mobile model test without email flag. |

## Tests

- `test_notification_preferences_schema.py`, `test_profile_router.py`: no `email_digest_enabled` in contract.
- `notification_preferences_model_test.dart`: parsing without email field.
