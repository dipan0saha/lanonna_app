# RCA: Event titles disagree with calendar catalog copy (#424)

| Field | Value |
|-------|--------|
| **Issue** | [#424](https://github.com/dipan0saha/lanonna_app/issues/424) (item 2) |
| **Status** | Fixed |
| **Date** | 2026-10-24 |
| **Related** | [#412](https://github.com/dipan0saha/lanonna_app/issues/412), [#416](https://github.com/dipan0saha/lanonna_app/issues/416) |

## Summary

The same catalog event showed different capitalization depending on how it was created: the AI suggestion list (catalog) said **"Baby shower"** and **"20-week anatomy scan"**, while a first-moment seed stored **"Baby Shower"** and an event saved from the suggestion stored **"20-Week anatomy scan"**.

## Root cause

Two independent defects, plus a test that hid the first one:

1. **First-moment preset labels drifted from the catalog.** `first_moment_presets.py` (API, writes `events.title` on seed) and the matching onboarding chip strings in `app_en.arb` used Title Case (`"Gender Reveal"`, `"Baby Shower"`, `"Due Date"`, `"First Holidays"`), while `assets/calendar/event_suggestions.json` and the rest of the event copy use sentence case.
2. **The app's sentence-case formatter capitalized the first letter even when a sentence starts with a digit.** `applySentenceCase` (used by the prose input formatter while typing and by `normalizeForSubmit` on save) skipped non-letters until it found a letter, so a catalog title prefilled into the event form, `"20-week anatomy scan"`, was saved as `"20-Week anatomy scan"`. The same defect turned user text like `"3.5 kg"` into `"3.5 Kg"` app-wide.
3. `test_first_moment_preset_parity.py` compared event preset labels to the catalog with `casefold()`, so (1) passed CI. Registry presets already required exact parity (#412).

## Decision

- **Source of truth:** `apps/mobile/assets/calendar/event_suggestions.json`. Anything that writes a catalog-backed title must produce that exact string, enforced by tests in CI, the same pattern as registry presets (#412).
- **No runtime catalog lookup on the server.** The API image only contains `services/` and `packages/` (`.gcloudignore`, `services/api/Dockerfile`), so the app asset is not available at runtime; and rewriting a submitted title by `catalog_suggestion_id` would silently discard a user's edit (pick "Baby shower", rename it "Sarah's baby shower"). The server stores the title it is given.
- **App submit keeps what the user sees.** With the formatter fixed, every catalog title is a fixed point of `formatProseSentence`, so a prefilled, unedited title is saved exactly as the catalog has it, and an edited one is saved as typed (sentence-cased).
- **All first-moment event labels are sentence case**, including presets with no catalog row (`Due date`, `First holidays`), so seeded events read consistently with catalog events.

Existing rows seeded before this fix keep their old titles (titles are user-editable; dev data only, prod has none).

## Fix

| Layer | Change |
|-------|--------|
| `apps/mobile/lib/core/input/prose_sentence_input.dart` | A sentence that starts with a digit is already started; nothing in it is uppercased. |
| `services/api/src/lanonna_api/first_moment_presets.py` | `Gender reveal`, `Baby shower`, `Due date`, `First holidays`. |
| `apps/mobile/lib/l10n/app_en.arb` (+ generated l10n) | Same four chip labels. |
| `services/api/tests/test_first_moment_preset_parity.py` | Case-sensitive equality with the catalog. |
| `apps/mobile/test/event_title_catalog_parity_test.dart` | Every catalog title survives `formatProseSentence` unchanged; first-moment chips equal the catalog title. |
| `apps/mobile/test/prose_sentence_input_test.dart` | Digit-start cases. |

## Deploy notes

API deploy for the seed labels; mobile build for the formatter and chip labels. No migration.

## References

- `apps/mobile/assets/calendar/event_suggestions.json`
- `services/api/src/lanonna_api/first_moment_presets.py`
- `services/api/tests/test_first_moment_preset_parity.py`
- `apps/mobile/test/event_title_catalog_parity_test.dart`
