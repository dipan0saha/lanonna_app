# RCA: Signed-in cold start serializes Home APIs behind `/v1/app/version`

## Symptom

On a signed-in Android cold launch against dev, API logs show **`GET /v1/app/version?platform=android` first**, then the **six Home/startup reads** (`/v1/onboarding/status`, `/v1/babies`, `/v1/babies/{id}/home-summary`, `/v1/me/account`, `/v1/me/notifications/unread-count`, plus any second baby-list read from title resolve) **only begin ~0.75–0.9 s later** — roughly the version round-trip. Home feels slow to populate even though the version gate is non-blocking for supported builds.

## What we traced

| Layer | File | Role on cold start |
|-------|------|-------------------|
| Entry | [`main.dart`](../../apps/mobile/lib/main.dart) | Firebase + parallel `bootstrapLaNonnaApp` + App Check activation; no HTTP yet. |
| Graph | [`bootstrap.dart`](../../apps/mobile/lib/bootstrap.dart) | Builds `ApiClient`, repos, `AppSession`; `appCheck.prefetch()` when signed in; **no network** before `runApp` (by design since #241). |
| First frame | [`app.dart`](../../apps/mobile/lib/app.dart) | Post-frame `AppSession.refreshFromApi()` for signed-in users (removed by this fix). |
| Version | [`app_version_gate.dart`](../../apps/mobile/lib/core/version/app_version_gate.dart) | **`didChangeDependencies`** started `PackageInfo` + `getJsonPublic('/v1/app/version')` — historically the **only** request kicked off during the first `MaterialApp` build. |
| Router | [`app_router.dart`](../../apps/mobile/lib/core/router/app_router.dart) | `redirectFor` can send `/home` immediately when cached onboarding status exists; does **not** await version. |
| Session | [`app_session.dart`](../../apps/mobile/lib/features/onboarding/presentation/app_session.dart) | `refreshFromApi` → `GET /v1/onboarding/status`; was **not** started until after first frame (#241 deferral). |
| Shell | [`shell_chrome_sync.dart`](../../apps/mobile/lib/features/shell/presentation/shell_chrome_sync.dart) | `resolveSelectedBaby` + `refreshUnreadCount` + `ensureAccountLoaded` when `MainShellScreen` mounts. |
| Home | [`home_screen.dart`](../../apps/mobile/lib/features/home/home_screen.dart) | `_load()` → speculative `home-summary` + `resolveSelectedBaby` when the Home tab widget mounts. |
| Tokens | [`api_client.dart`](../../apps/mobile/lib/core/api/api_client.dart) | Authorized GETs await Firebase **ID token** + **App Check** header in parallel; version uses **`getJsonPublic`** (no tokens). |
| App Check | [`app_check_token_source.dart`](../../apps/mobile/lib/core/app_check/app_check_token_source.dart) | Single-flight `getToken`; prefetch in bootstrap overlaps attestation — **not** the version serializer. |
| Biometric lock | [`biometric_app_lock.dart`](../../apps/mobile/lib/core/auth/biometric_app_lock.dart) | May `ensureAccountLoaded` post-frame for lock policy; shares account single-flight; **does not** gate other startup GETs. |

## Root cause

**Startup network work was scheduled from the widget tree in sequence after the version check had already claimed the connection window**, not from one coordinated launch point.

1. **`AppVersionGate`** (outer `MaterialApp.builder` wrapper) began the public version GET in **`didChangeDependencies` on the first frame** — the earliest HTTP in the app UI.
2. **Signed-in data loading** was split across **later hooks**:
   - `LaNonnaApp` → post-frame `refreshFromApi` (onboarding status),
   - `ShellChromeSync` / `HomeScreen` → baby list, account, unread, home-summary **only after** the router built `MainShellScreen` and the Home branch.
3. Those layers are **correct for UX** (show carousel/shell immediately, use cached routing offline) but they **start authorized GETs tens to hundreds of milliseconds after** the version call, and on dev emulators the **~0.8 s version RTT** matches the gap before the burst of six calls in logs.
4. **Not** the cause: App Check single-flight (version does not use App Check), router redirect waiting on version (it does not), or biometric lock blocking API (overlay only; prefetch is separate).

So the ~0.8 s is primarily **version wall time plus deferred scheduling of signed-in prefetch**, not ID-token work blocking the public endpoint.

## Fix (architecture)

- **`AppVersionService`** — the version check runs **once per process** (a latch, not a re-running single-flight), started in **`bootstrapLaNonnaApp`** for every launch. `AppVersionGate` only watches it and renders the block; it never starts a check (re-starting from the gate looped `/v1/app/version` whenever the block notified).
- **`startSignedInStartupPrefetch`** — when `currentUser != null`, start **onboarding status, account, unread, baby resolve, and speculative home-summary** from bootstrap **in parallel with** the version check. It is the **only cold-start owner** of `AppSession.refreshFromApi` (the old post-frame refresh in `LaNonnaApp` is gone). `refreshFromApi` is deliberately **not** single-flight: callers after a mutation must not join a request that started before it.
- **No duplicate reads when the UI mounts:** account and baby list are cached single-flights; `ShellChromeSync` reads the unread count with `NotificationsRepository.unreadFreshFor` and `HomeScreen`'s first load reads the summary with `HomeRepository.summaryFreshFor`; speculative home-summary reads share one in-flight request per baby (non-speculative, post-mutation reads never join).

**Semantics preserved**

- **Force-update:** when the installed build is below minimum, `AppVersionGate` still replaces the tree with `AppVersionBlockScreen` (full-screen; only store action). Prefetched home data is discarded visually; user cannot interact with Home.
- **Offline cold start:** `ApiClient` still throws offline for network reads; session restores cached onboarding status; identity/baby selection stores unchanged (PR #346 / offline routing).
- **App Check:** still one in-flight SDK read; prefetch at bootstrap unchanged.

## How to verify (emulator + dev API logs)

1. Signed-in user with main-app access; kill app.
2. `adb shell am start -W -n com.lanonna.app.dev/com.lanonna.app.MainActivity` (or your dev application id).
3. In API request logs, **`/v1/app/version` and the signed-in GETs should start in the same second** (overlapping), not ~0.8 s apart.
4. Optional: temporarily set a high `minimum_version` in `app_versions` — app shows update block, no Home interaction.
5. Airplane mode cold start — cached shell/home/offline banner behavior unchanged.

## Related

- [perf-audit-2026-10.md](../perf-audit-2026-10.md) — PERF-MOB startup notes
- [development.md](../development.md) — cold-start table
- [#336](https://github.com/lanonna/lanonna_app/pull/336) — parallel bootstrap + App Check prefetch
- [#346](https://github.com/lanonna/lanonna_app/pull/346) — biometric cold-start lock settlement
