# RCA: Issue #393 — Gallery Favorites view unreachable

## Summary

`/gallery/favorites` (`GalleryViewMode.favorites`, API `sort=favorites`) exists and works, but no in-app navigation reaches it after HOME-006 QA (GAL-004 / #393).

## Root cause

Issue **#67** intentionally removed Home teaser tiles (RSVP reminders, gallery favorites, registry highlights) because **Recent activity** and feature tabs own those flows. Commit `398181c` deleted the Home “Gallery Favorites – View all” link in `home_teasers_section.dart` without adding a replacement on the Gallery tab.

That matches PRD L190: gallery favorites are **not** on Home; users open them from **Gallery**. The Favorites **feature** was not retired—only the Home entry point was.

## Decision

**Restore access on the Gallery screen**, not on Home. Add an All / Recent / Favorites selector in the Gallery header that routes to `GalleryRoutes.gallery`, `GalleryRoutes.recent`, and `GalleryRoutes.favorites`.

Do **not** delete favorites routes, repository sort mode, or API `sort=favorites` (still required by FR-GAL-004).

## Fix

- `GalleryViewModeSelector` widget (segmented control, shared styling).
- Gallery screen shows selector under the page title for all three modes.
- Widget test: selector visible and favorites label present.

## Test plan

- `apps/mobile/test/gallery_view_mode_selector_test.dart`
