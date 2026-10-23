# RCA: Issue #392 — System announcement banners omit title

## Summary

Home renders dismissible system announcement banners from `GET /v1/babies/{id}/home-summary`, but users only see the body text. Admin-authored titles (required in `system_announcements.title`) never appear, so messages like “Scheduled maintenance” / “Saturday 2–4 AM” lose their headline.

## Root cause

`HomeSystemAnnouncementsSection` built a raw `MaterialBanner` with `content: Text(item.body)` and never bound `item.title`. The API already returns `title` in `system_announcements[]` (`domain/home.py`).

There was no shared announcement banner widget; the Home section inlined `MaterialBanner` without the title/body layout used elsewhere in the app.

## Fix

- New shared `AppBanner` (`core/widgets/app_banner.dart`): a themed `MaterialBanner` with an optional semibold title above the message, an optional leading icon, and actions. A blank title is omitted.
- `HomeSystemAnnouncementsSection` passes `title`, `body` and the campaign icon.
- The Home load-error banner (`home_screen.dart`) uses the same widget, so Home has no raw `MaterialBanner` left.
- No separate semantics label: the title and message `Text`s are read in order.

## Tests

- `apps/mobile/test/app_banner_test.dart`: title renders above the message; a blank title shows only the message; `HomeSystemAnnouncementsSection` renders the API title, body and icon.
