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

The mobile mirror in `first_moment_presets.dart` duplicated the same wrong offsets (display-only today; API is authoritative at seed time).

**Clamping:** When the due date is soon, raw offsets can land before today. Seeded onboarding events should not appear in the past; clamp each event date to `max(computed_date, today)` in the domain layer when seeding expecting presets.

## Root cause — AI suggestion dedupe

Calendar AI availability (`event_suggestion_availability.dart`) hides catalog rows whose `catalog_suggestion_id` is already claimed on an event.

`insert_seed_event()` inserted title and `starts_at` only — no `catalog_suggestion_id`. First-moment preset ids (`gender_reveal`, `baby_shower`, …) align with `assets/calendar/event_suggestions.json` ids, but seeded rows never set the column, so the client could not suppress matching suggestions.

**Decision:** set `catalog_suggestion_id` to the **preset id** when seeding first-moment events (same pattern as manual event create and registry AI seeds). Dedupe stays catalog-id based; no title matching heuristics.

## Fix

| Layer | Change |
|-------|--------|
| `first_moment_presets.py` | Expecting `day_offset` values −14 / −7 / 0; add `event_date_for_preset(anchor, offset, today)` with past clamping for expecting seeds. |
| `domain/onboarding.py` | Use clamped date helper when lifecycle is expecting; born path unchanged. |
| `repositories/first_moment.py` | `insert_seed_event(..., catalog_suggestion_id=...)`. |
| `first_moment_presets.dart` | Mirror expecting offsets for consistency. |

## Test plan

- API `test_first_moment_presets.py` (new): expecting offsets and clamp when due date is near.
- API `test_onboarding_domain.py`: extend `seed_first_moment` mocks to assert `starts_at` dates and `catalog_suggestion_id` for expecting presets.
- Mobile `event_suggestion_availability_test.dart`: optional case — events with `catalogSuggestionId` from seed hide catalog rows (if not covered by API-only tests).
