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

For an **expecting** baby with due date **D** (fallback when missing: today + 90 days, same as onboarding anchor):

- **Earliest:** `max(utc_today(), D − 42 days)` — no past guesses for an unborn baby; up to six weeks before due.
- **Latest:** `D + 42 days` — six weeks after due for late arrivals.

Votes outside the window are rejected with **422** and code `birthdate_vote_out_of_range`. **Histograms and home “top guess”** omit out-of-range stored votes (legacy bad rows stay in DB but are not shown).

## Fix

| Layer | Change |
|-------|--------|
| **API** | `domain/birthdate_vote_window.py` — single source for bounds + validation; `UnprocessableEntityError` (422). `get_predictions` returns `birthdate_vote_min` / `birthdate_vote_max` and filters histogram. Home payload filters top guess. |
| **Mobile** | `birthdate_prediction.dart` uses server bounds from predictions payload for picker `firstDate`/`lastDate`. |

## Tests

- `test_birthdate_vote_window.py`: bounds math, 422 on out-of-range, histogram filter.
- `test_fun_predictions_http.py`: HTTP 422 for 2099.
- `birthdate_prediction_test.dart`, `predictions_tab_birthdate_test.dart`: picker bounds from payload.
