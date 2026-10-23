# RCA: Issue #392 — System announcement banners omit title

## Summary

Home renders dismissible system announcement banners from `GET /v1/babies/{id}/home-summary`, but users only see the body text. Admin-authored titles (required in `system_announcements.title`) never appear, so messages like “Scheduled maintenance” / “Saturday 2–4 AM” lose their headline.

## Root cause

`HomeSystemAnnouncementsSection` built a raw `MaterialBanner` with `content: Text(item.body)` and never bound `item.title`. The API already returns `title` in `system_announcements[]` (`domain/home.py`).

There was no shared announcement banner widget; the Home section inlined `MaterialBanner` without the title/body layout used elsewhere in the app.

## Fix

- Add `AppSystemAnnouncementBanner` under `core/widgets/` — title (semibold) above body, combined semantics label, standard campaign icon.
- Use it from `HomeSystemAnnouncementsSection`.
- Widget test asserts both strings render.

## Test plan

- `apps/mobile/test/app_system_announcement_banner_test.dart` — title + body visible; semantics label includes both.
