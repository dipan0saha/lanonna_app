# RCA: Home pull-to-refresh fails silently with stale summary (#421)

## Summary

After Home has loaded once, pull-to-refresh runs for ~15s and stops with no snackbar or inline error while the previous summary stays on screen. This happens offline and on “connected but failing” networks (e.g. broken DNS). A failed refresh looks like a successful one with no changes.

## Root cause

`HomeRepository._requestHomeSummary` catches network and 5xx errors and, when a cached summary exists, always returns `HomeSummaryLoaded(cached)` (`_shouldServeStaleSummary`). That is correct for passive loads (offline, tab revisit within freshness window) but hides failures from explicit refreshes.

`HomeScreen._load` (wired to `ShellTabLayout` pull-to-refresh) treats any `HomeSummaryLoaded` as success. `reportTabLoadFailure` / snackbars only run when `resolveSelectedBaby` throws; the baby list comes from `BabyListCache` and does not throw on refresh failure.

Other shell tabs already surface reload failures via `reportTabLoadFailure` when `hasPayload` is true; Home was the outlier because the repository swallowed summary errors.

## Fix

The repository reports what happened, and the screen decides whether the user should see it.

| Layer | Change |
|-------|--------|
| `HomeSummaryLoaded` | `refreshError` is set whenever the cached summary is served because the request failed. The repository no longer takes a flag that changes this. |
| `HomeScreen._load` | An explicit refresh (`summaryMaxAge == null`: pull-to-refresh or a baby-context reload) with a `refreshError` calls `reportRefreshFailure` and keeps the cached content. Passive loads such as tab revisits stay quiet. `HomeSummaryFailed` (nothing cached) keeps the existing inline error, so one failure never shows both a banner and a snackbar. A failed switch to another baby never shows the previous baby's summary. |
| `core/presentation/tab_load_failure.dart` | `reportRefreshFailure(context, error)` is the single refresh-failure snackbar (`AppSnackBar.showAlert` + `apiErrorMessage`). `reportTabLoadFailure` uses it when content is on screen. |
| `core/widgets/app_refresh_indicator.dart` | `AppRefreshIndicator(onRefresh, child)` is the shared pull-to-refresh. If `onRefresh` throws, it calls `reportRefreshFailure`, so no screen can fail a pull silently. All pull-to-refresh sites use it (shell tabs, account, calendar, fun, AI scaffolds). |
| `scripts/check-no-raw-refresh-indicator.sh` | A CI guard (also in `verify-dev-prerequisites.sh`) that fails when `lib/` uses a raw `RefreshIndicator` outside the wrapper. |
| `account_screen.dart`, `calendar_upcoming_screen.dart` | These screens swallowed refresh errors or blanked loaded content. They now use `reportTabLoadFailure(hasPayload: ...)` like the other tabs: a snackbar when content is on screen, the inline error otherwise. |
| Tests | `home_repository_test` (`refreshError` is set on a stale serve and null on success), `home_pull_refresh_failure_test`, and `app_refresh_indicator_test` (a throwing refresh shows the snackbar and keeps the content). |

Follow-up, not in this fix: the AI suggestion screens already show a snackbar on refresh failure, but they replace the list with a spinner while refreshing.

## References

- GitHub #421 (OFF-002)
- `apps/mobile/lib/features/home/data/home_repository.dart`
- `apps/mobile/lib/features/home/home_screen.dart`
- `apps/mobile/lib/core/presentation/tab_load_failure.dart`
