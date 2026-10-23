# RCA: Birthdate prediction accepts any date (#413)

| Field | Value |
|-------|--------|
| **Issue** | [#413](https://github.com/dipan0saha/lanonna_app/issues/413) |
| **Status** | Fixed |
| **Date** | 2026-10-23 |

## Symptom

`PUT …/fun/predictions/birthdate` accepted dates such as `2020-01-01` and `2099-12-31` with **200**. The app date picker used hard-coded `2020`–`2035`. Out-of-range guesses appeared in **Popular Dates** / home teasers.

## Root cause

`set_birthdate_vote` only checked membership and `ensure_fun_writes_open` (baby must be **expecting**). No date validation. Mobile `predictions_tab.dart` used fixed picker bounds unrelated to the baby’s due date.

FR-GAM-002 does not specify a window; product needs a bounded, due-centric range.

## Decision (valid window)

For an **expecting** baby with due date **D**:

- **Open window** (what a vote may be saved as): `max(utc_today(), D − 42)` … `D + 42` — no past guesses for an unborn baby; six weeks either side of due. If today is already past `D + 42`, the window is today only, so an overdue baby can still be guessed.
- **No due date:** `utc_today()` … `utc_today() + 294` (40 weeks + 2).
- **Shown window** (what counts in Popular Dates and the home top guess): `D ± 42` with **no** today clamp, so a fair guess does not disappear just because its day has passed. Votes outside it (legacy rows saved before this fix) stay in the DB but are never counted.

Out-of-range writes are rejected with **400** `birthdate_vote_out_of_range` — the same status as every other invalid input.

## Fix

| Layer | Change |
|-------|--------|
| **API** | `domain/birthdate_vote_window.py` is the one source: open window, shown window, validation. `get_predictions` returns `birthdate_vote_min` / `birthdate_vote_max` (open window). Popular Dates (`repositories/fun.py`) and the home top guess (`repositories/home_counts.py`) filter in SQL through `repositories/birthdate_votes.py`. |
| **Mobile** | Picker bounds come only from `birthdate_vote_min` / `birthdate_vote_max` (no client copy of the rule). The picker opens on the pending pick, saved guess or due date moved into that window, so an old saved guess cannot crash `showDatePicker`. |

## Tests

- `test_birthdate_vote_window.py`: bounds math, overdue and no-due cases, 400 on out-of-range.
- `test_fun_predictions.py`, `test_fun_predictions_http.py`: payload bounds, histogram uses the shown window, HTTP 400 for 2099.
- `test_birthdate_vote_window_postgres.py`: out-of-window votes never count; a guess whose day has passed still counts.
- `birthdate_prediction_test.dart`, `predictions_tab_birthdate_test.dart`: window from the payload; picker initial date clamped into it.
