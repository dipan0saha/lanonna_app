# RCA: Event titles disagree with calendar catalog copy (#424)

| Field | Value |
|-------|--------|
| **Issue** | [#424](https://github.com/dipan0saha/lanonna_app/issues/424) (item 2) |
| **Status** | Fixed |
| **Date** | 2026-10-24 |
| **Related** | [#412](https://github.com/dipan0saha/lanonna_app/issues/412), [#416](https://github.com/dipan0saha/lanonna_app/issues/416) |

## Summary

Calendar AI suggestions and stored event titles for the same catalog item showed different capitalization (e.g. catalog **"Baby shower"** vs seeded or saved **"Baby Shower"**). Users see one string in the suggestion list and another on the calendar after save or first-moment seed.

## Root cause

Three writers, no canonical title:

1. **`assets/calendar/event_suggestions.json`** — sentence-case titles (source for AI suggestions in the app).
2. **`first_moment_presets.py`** — Title Case labels (`"Baby Shower"`, `"Gender Reveal"`) written directly into `events.title` on onboarding seed.
3. **Event form submit** — `AppTextInputPolicy.normalizeForSubmit(AppTextInputKind.prose, …)` applies sentence formatting to whatever the user typed, which can diverge from the catalog when the field was prefilled from a suggestion.

`test_first_moment_preset_parity.py` only asserted `casefold()` equality for events, so the mismatch shipped. Registry presets already required exact catalog name parity (#412).

## Decision

- **Single source of truth:** `assets/calendar/event_suggestions.json` for any event with a `catalog_suggestion_id` that appears in that file.
- **Server normalization:** When `catalog_suggestion_id` is set on create (calendar API) or seed (`insert_seed_event` via onboarding), replace the client/preset title with the catalog title.
- **App submit:** When creating an event with `catalogSuggestionId`, submit the catalog title instead of prose-normalized field text (server still canonicalizes).
- **Onboarding chips:** ARB labels for catalog-backed presets aligned to catalog sentence case so chips match AI copy.
- **`due_date`** and other presets with no catalog row keep preset labels unchanged.

## Fix

| Layer | Change |
|-------|--------|
| `event_suggestions_catalog.py` (new) | Load catalog JSON (same path as parity tests); `canonical_event_title(catalog_id)`. |
| `domain/calendar.py` | `create_calendar_event` uses canonical title when `catalog_suggestion_id` maps to catalog. |
| `domain/onboarding.py` | Seed events use canonical title when preset id is in catalog. |
| `first_moment_presets.py` | Labels for catalog-backed expecting events match JSON. |
| Mobile ARB / l10n | `labelBabyShower`, `labelGenderReveal` match catalog. |
| `EventSuggestionsCatalog` | `titleForId` for create submit. |
| `event_form_screen.dart` | Create with catalog id submits catalog title. |
| Tests | Exact catalog parity for presets; calendar domain test for canonical title on create; Flutter catalog title helper test. |

## Deploy notes

API deploy for server normalization; mobile build for form/labels.

## References

- `apps/mobile/assets/calendar/event_suggestions.json`
- `services/api/src/lanonna_api/event_suggestions_catalog.py`
- `services/api/tests/test_event_suggestions_catalog_parity.py`
