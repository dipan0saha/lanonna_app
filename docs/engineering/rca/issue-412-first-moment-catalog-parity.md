# RCA: First-moment seeds — born clamping and catalog id parity (#412)

| Field | Value |
|-------|--------|
| **Issue** | [#412](https://github.com/dipan0saha/lanonna_app/issues/412) |
| **Status** | Fixed |
| **Date** | 2026-10-23 |
| **Related** | [#403](https://github.com/dipan0saha/lanonna_app/issues/403) / PR #404 |

## Summary

Three gaps left out of the #403 fix:

1. **Born** first-moment event dates count forward from `actual_birth_date` without clamping to `utc_today()`, so a baby born weeks ago gets past events.
2. Born preset **`first_checkup`** / "First Checkup" does not match calendar catalog **`first_pediatric_visit`** / "First pediatric visit", so AI suggestions still offer the checkup after seeding.
3. Registry first-moment seeds insert **name only** (no `catalog_suggestion_id`) with preset ids and titles that do not match `registry_suggestions.json`, so registry AI keeps offering the same items.

## Root cause

- **Dates:** `_first_moment_event_starts_at` used `event_starts_at(birth, offset)` for born babies while expecting presets used `event_date_for_expecting_preset` (clamp to today).
- **Calendar ids:** Preset list and seed path used `first_checkup`; the app catalog uses `first_pediatric_visit`. Seeding set `catalog_suggestion_id=preset.id`, so dedupe never matched.
- **Registry:** `insert_seed_registry_item` had no catalog column; preset ids (`swaddles`, `crib`, …) and labels were ad hoc, not the catalog ids/names used by registry AI (`swaddle_blankets`, `crib_mattress`, …).

## Decision

- **One id per catalog-backed preset:** preset id = `catalog_suggestion_id` on seed (same as manual create / #403 expecting events). Titles in `first_moment_presets.py` match catalog JSON names exactly.
- **Born clamping:** `event_date_for_born_preset` mirrors expecting: `max(birth_date + offset, utc_today())`.
- **Born registry keeps its items:** Diapers (newborn) → `diaper_stockpile`; Onesies and Bottles have no catalog row and stay custom (no `catalog_suggestion_id`). Diaper pail / bottle sterilizer are different products, so they are not substitutes.
- **Existing data — backfill, no alias:** migration `047` links seeds made before this fix: events `first_checkup` → `first_pediatric_visit`; registry rows named `Swaddles` / `Crib` / `Diapers` with no catalog id → `swaddle_blankets` / `crib_mattress` / `diaper_stockpile`. One row per baby, skipped when the baby already has that id; titles are kept. Idempotent. No request alias for `first_checkup` is needed: preset ids are only sent by onboarding, and the server ignores unknown ids (older builds just skip that preset).

## Fix

| Layer | Change |
|-------|--------|
| `first_moment_presets.py` | Born date helper + clamp; rename `first_checkup` → `first_pediatric_visit`; registry presets use catalog ids/names; optional `catalog_suggestion_id` on registry presets. |
| `domain/onboarding.py` | Born path uses clamped helper; registry seed passes catalog id. |
| `repositories/first_moment.py` | `insert_seed_registry_item(..., catalog_suggestion_id=...)`. |
| Mobile | `first_moment_presets.dart`, labels/ARB aligned to catalog; parity test unchanged contract. |
| DB | `047_first_moment_catalog_ids_backfill.sql`. |
| Tests | API born clamp + catalog ids; mobile availability hides seeded catalog rows. |

## Tests

- `test_first_moment_presets.py`: born clamp when birth is in the past.
- `test_onboarding_domain.py`: `first_pediatric_visit` catalog id; registry `catalog_suggestion_id`; born old-baby dates ≥ today.
- `event_suggestion_availability_test.dart`: seeded `first_pediatric_visit` hides catalog row.
- `registry_suggestion_availability_test.dart`: seeded `crib_mattress` hides catalog row.
- `test_first_moment_preset_parity.py`: every catalog-backed preset matches a catalog row (registry names exactly; event titles case-insensitively).
- `test_first_moment_catalog_backfill_postgres.py`: `047` links old seeds, skips conflicts, and is safe to re-run.
