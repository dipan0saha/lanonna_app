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

- Remove the dead **email digest** switch and stop accepting `email_digest_enabled` on notification-preferences PATCH; migration `048` drops the column.
- Relabel digest options: weekly → **Weekly push summary**; daily → **In-app only** / “Inbox only, no push”; real-time → “A push for each update”. Each option shows its summary as the subtitle, and onboarding copy says the same.
- Scope copy: notification preferences apply to **your account** across all babies you follow (not “for {babyName}”).

Weekly delivery still requires `notification_digest = weekly` and `push_notifications_enabled` (unchanged worker behavior).

## Fix

| Layer | Change |
|-------|--------|
| **Mobile** | Remove email switch from `notification_preferences_screen.dart`; update ARB intro/frequency titles and digest summary strings. |
| **API** | Drop `email_digest_enabled` from notification-preferences GET/PATCH payload, `update_notification_preferences` and the profile column list. |
| **DB** | `048_drop_app_users_email_digest_enabled.sql` (contract step; apply after the API deploy). |
| **Docs** | `requirements.md` data table: digest frequency + push toggle only. |
| **Tests** | Update preference schema/router tests; mobile model test without email flag. |

## Tests

- `test_notification_preferences_schema.py`, `test_profile_router.py`: no `email_digest_enabled` in contract.
- `notification_preferences_model_test.dart`: parsing without email field.
- `domain_value_labels_test.dart`, `account_edit_profile_test.dart`: push / in-app summary labels.
