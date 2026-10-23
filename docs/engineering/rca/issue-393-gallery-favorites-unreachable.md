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

- New shared `AppToggleChipBar` / `AppToggleChipOption` in `core/widgets/app_chip.dart`. It is a scrollable row of core `AppToggleChip`s with one selected value. The AI suggestions scaffold previously built its tab row inline and now uses it too, so the app has one view-switcher pattern and no Material `SegmentedButton` or chips (docs/product/README.md).
- `GalleryViewModeSelector` builds that bar with All photos / Recent Photos / Favorites and `context.go`s the mode's route.
- The Gallery screen title is always "Gallery". The selector and the section label already name the view, so the title no longer repeats it per mode. The selector is hidden when there is no baby profile.
- Prototype: `docs/prototype/nonna_combined_prototype.html` shows only the "All Photos" section label on the Gallery tab. The selector follows the existing AI-suggestions chip-tab pattern rather than adding new styling.

## API

`GET /baby-profiles/{id}/photos?sort=default|recent|favorites` already exists. Recent means the last 30 days, newest first. Favorites means squished photos only, most squishes first. Favorites already had test coverage (`test_gallery_permissions.py`, `test_tombstoned_participation.py`). `tests/integration/test_photo_list_sort_postgres.py` now covers all three orders against Postgres.

## Test plan

- `apps/mobile/test/gallery_view_mode_selector_test.dart`: three shared toggle chips, All selected by default; tapping each view routes to it and selects it.
- `services/api/tests/integration/test_photo_list_sort_postgres.py`
- Device: open the Gallery tab, switch between All, Recent and Favorites, and confirm each list. Take before and after screenshots.
