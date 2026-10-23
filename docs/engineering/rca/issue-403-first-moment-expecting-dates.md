# RCA: Issue #403 — First-moment expecting presets dated on/after due date

## Summary

For an **expecting** baby, onboarding first-moment presets create calendar events on or after the due date (e.g. Gender Reveal on the due date, Baby Shower at due + 7d, "Due Date" at due + 14d). Born-baby presets (anchor = birth date, offsets 0 / +7 / +14) behave correctly.

AI Suggestions still offers "Gender reveal" after the user seeded that event during onboarding.

## Root cause — dates

`domain/onboarding.py` `_anchor_date()` returns `expected_birth_date` for expecting babies. `seed_first_moment()` computes `event_starts_at(anchor, preset.day_offset)` using offsets from `first_moment_presets.py`.

Expecting presets were defined with the **same positive offsets** as born presets (`0`, `7`, `14`), as if counting forward from the anchor. For expecting babies the anchor is the **due date**, so those offsets should count **backward** for pre-birth milestones and **zero** for the due-date milestone:

| Preset | Intended date | Correct offset from due date |
|--------|----------------|------------------------------|
| Gender Reveal | Before due | −14 days |
| Baby Shower | Before due | −7 days |
| Due Date | On due date | 0 |

The mobile `first_moment_presets.dart` duplicated the same wrong offsets, but nothing in the app read `dayOffset`: the app sends preset ids and the API computes dates.

**Clamping:** When the due date is soon, raw offsets can land before today. Seeded onboarding events should not appear in the past; clamp each event date to `max(computed_date, today)` in the domain layer when seeding expecting presets.

**“Today” for clamping:** Use `utc_today()` from `domain/date_validation.py` (UTC calendar date from `datetime.now(timezone.utc).date()`), same as home “days to due”, birth-date validation, and other API calendar-day logic. Do not use `date.today()` (server local timezone).

## Root cause — AI suggestion dedupe

Calendar AI availability (`event_suggestion_availability.dart`) hides catalog rows whose `catalog_suggestion_id` is already claimed on an event.

`insert_seed_event()` inserted title and `starts_at` only — no `catalog_suggestion_id`. First-moment preset ids (`gender_reveal`, `baby_shower`, …) align with `assets/calendar/event_suggestions.json` ids, but seeded rows never set the column, so the client could not suppress matching suggestions.

**Decision (new seeds):** set `catalog_suggestion_id` to the **preset id** when seeding first-moment events (same pattern as manual event create and registry AI seeds).

**Legacy rows (no backfill):** Events created before this fix still have `catalog_suggestion_id` null. Calendar AI dedupe in `event_suggestion_availability.dart` also treats an existing event as claiming a catalog row when its **title** matches a catalog suggestion title (case- and whitespace-insensitive), via shared `claimedCatalogIdsWithTitleFallback` in `core/catalog/suggestion_availability.dart`. That covers seeded “Gender Reveal” vs catalog “Gender reveal” without migrating old rows.

## Fix

| Layer | Change |
|-------|--------|
| `first_moment_presets.py` | Expecting `day_offset` values −14 / −7 / 0; `event_date_for_expecting_preset` clamps with `utc_today()`. |
| `domain/onboarding.py` | Use clamped date helper when lifecycle is expecting; born path unchanged. |
| `repositories/first_moment.py` | `insert_seed_event(..., catalog_suggestion_id=...)`. |
| `first_moment_presets.dart` | Drop the unused `dayOffset` mirror. The API is the one source of truth for titles, dates and catalog ids; the app keeps ids only (`FirstMomentPreset`). `tests/test_first_moment_preset_parity.py` fails if app and API ids drift. |
| `domain/onboarding.py` (review) | One `_first_moment_event_starts_at(baby, offset)` decides born vs expecting; the unknown-due-date fallback uses `utc_today()` too. |
| `event_suggestion_availability.dart` | Title fallback dedupe for events missing `catalog_suggestion_id`. |

## Test plan

- API `test_first_moment_presets.py` (new): expecting offsets and clamp when due date is near.
- API `test_onboarding_domain.py`: extend `seed_first_moment` mocks to assert `starts_at` dates and `catalog_suggestion_id` for expecting presets.
- Mobile `event_suggestion_availability_test.dart`: optional case — events with `catalogSuggestionId` from seed hide catalog rows (if not covered by API-only tests).

## Dedupe layer decision (review)

The calendar AI catalog (`assets/calendar/event_suggestions.json`) and its titles live in the app, and availability is already computed in the app (`availableEventSuggestions`), so the title fallback belongs there, not in the API. The API's job stays the hard rule: one event per `catalog_suggestion_id` per baby. Matching is exact after trim, lower-case and whitespace collapse, and only for events with no `catalog_suggestion_id`. That covers legacy seeds ("Gender Reveal" vs catalog "Gender reveal") and hand-typed identical titles, without fuzzy matching. No backfill.

Known gaps, out of scope here:

- Born preset `first_checkup` ("First Checkup") does not match catalog `first_pediatric_visit` by id or title.
- Registry first-moment seeds (`swaddles`, `crib`, `diapers`) store no `catalog_suggestion_id`, and their titles differ from the registry catalog ("Crib & Mattress", …), so registry AI still offers them.
- Born presets count forward from the birth date without clamping, so an older baby's seeded events can be in the past.
