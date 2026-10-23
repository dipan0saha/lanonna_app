# RCA: Home pull-to-refresh fails silently with stale summary (#421)

## Summary

After Home has loaded once, pull-to-refresh runs for ~15s and stops with no snackbar or inline error while the previous summary stays on screen. This happens offline and on “connected but failing” networks (e.g. broken DNS). A failed refresh looks like a successful one with no changes.

## Root cause

`HomeRepository._requestHomeSummary` catches network and 5xx errors and, when a cached summary exists, always returns `HomeSummaryLoaded(cached)` (`_shouldServeStaleSummary`). That is correct for passive loads (offline, tab revisit within freshness window) but hides failures from explicit refreshes.

`HomeScreen._load` (wired to `ShellTabLayout` pull-to-refresh) treats any `HomeSummaryLoaded` as success. `reportTabLoadFailure` / snackbars only run when `resolveSelectedBaby` throws; the baby list comes from `BabyListCache` and does not throw on refresh failure.

Other shell tabs already surface reload failures via `reportTabLoadFailure` when `hasPayload` is true; Home was the outlier because the repository swallowed summary errors.

## Fix

| Layer | Change |
|-------|--------|
| `HomeSummaryLoaded` | Optional `staleRefreshError` when cache is served but the network request failed on an explicit refresh. |
| `HomeRepository.fetchHomeSummary` | `allowStaleOnError` (default `true`). When `false`, failed requests set `staleRefreshError` on the loaded cache instead of pretending the fetch succeeded. |
| `HomeScreen._load` | Pass `allowStaleOnError: summaryMaxAge != null` so pull-to-refresh and baby-context reloads require a fresh summary or report failure. On `staleRefreshError`, call `reportRefreshFailure` (snackbar) while keeping cached content. Preserve `_summary` on hard `HomeSummaryFailed` when content is already on screen. |
| `core/widgets/app_refresh_indicator.dart` | Shared `AppRefreshIndicator` wrapper used everywhere `RefreshIndicator` appeared (shell tabs, account, calendar, fun, AI scaffolds). |
| `tab_load_failure.dart` | `reportRefreshFailure` documents the pull-to-refresh snackbar contract (delegates to `reportTabLoadFailure` with `hasPayload: true`). |

## References

- GitHub #421 (OFF-002)
- `apps/mobile/lib/features/home/data/home_repository.dart`
- `apps/mobile/lib/features/home/home_screen.dart`
- `apps/mobile/lib/core/presentation/tab_load_failure.dart`
