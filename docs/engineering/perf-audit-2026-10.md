# Performance audit — October 2026

Analysis-only audit of La Nonna across **Flutter Android** (`apps/mobile`), **FastAPI API** (`services/api`), **Pub/Sub worker** (`services/worker`), **Postgres migrations** (`infra/db/migrations`), and **Terraform / deploy** (`infra/`, `scripts/`). It builds on merged perf work in PRs [#332](https://github.com/lanonna/lanonna_app/pull/332)–[#338](https://github.com/lanonna/lanonna_app/pull/338) and checks whether newer changes [#345](https://github.com/lanonna/lanonna_app/pull/345)–[#358](https://github.com/lanonna/lanonna_app/pull/358) introduced regressions.

**How to use this doc:** Pick items from the ranked table by impact × effort; validate hypotheses in [Needs measurement](#needs-measurement) before large changes. Existing measurement guidance remains in [development.md](development.md) § Performance.

---

## Prior perf work (#332–#338) — applied app-wide?

| Fix (PR) | Intent | Applied app-wide? | Gaps / notes |
|----------|--------|-------------------|--------------|
| #332 | Single lossy WebP display encode | **Yes** for uploads via `DisplayPhotoUpload` / `display_encode.dart` | Local picks still decode full resolution in isolate before encode (expected). |
| #333–#334 | Pooled DB, `read_scope()`, bounded home/detail, shared URL signer, gzip ≥1 KB | **Yes** on server paths that use `read_scope()` and batch signing | Deploy does not set Cloud Run **concurrency** (see PERF-API-01). No HTTP caching headers (PERF-API-10). |
| #335 | Shared baby list, shell chrome sync, photo window, duplicate request reduction | **Mostly yes** | Gallery grid loads via `listPhotosPage` in `gallery_screen.dart` while `GalleryRepository.extendPhotoWindow` exists for detail swipe — two pagination paths (PERF-MOB-09). Inbox still loads one API page only (PERF-MOB-03). |
| #336 | Parallel startup, App Check single-flight, speculative home summary, launch screen | **Yes** in `main.dart` / `bootstrap.dart` | Signed-in cold start still runs Crashlytics bind + optional biometric lock account hydrate (#348/#346) after bootstrap. |
| #337 | Slot-sized decode, object-path cache keys, bundled fonts, lazy gallery grid | **Yes** for network images (`CachedSignedImage` / `DisplaySizedImage`) | Many primary tabs still use **non-builder** `ListView` with all children built at once (PERF-MOB-06). Photo detail renders **all** comments in a `Column` (PERF-MOB-07). |
| #338 | Dev API `min-instances=1`, App Check APIs in TF | **Dev yes** (`infra/env/dev.api.env`); **prod env file** also sets `API_MIN_INSTANCES=1` | Worker remains scale-to-zero (`services/worker/scripts/deploy.sh`). Prod SQL tier is variable-driven, not identical to dev `db-custom-1-3840`. |

---

## Regression review (#345–#358)

| PR | Feature | Perf impact | Verdict |
|----|---------|-------------|---------|
| #345 | Biometric sign-in after logout | Extra API round-trips only on biometric login/enroll (`BiometricSignInService`, `BiometricCredentialRepository`); no hot-path change for normal tabs | **No tab regression** |
| #346 | Biometric app lock on resume / cold start | `BiometricAppLock` may call `ensureAccountLoaded()` before lock (`biometric_app_lock.dart` ~151–161) and `setState` overlay; router/session listeners can defer lock to next frame (~185–196) | **Small cold-start / resume cost** when setting enabled; acceptable for security |
| #348 | Crashlytics + prod flavor | `startCrashReporting` in `bootstrap.dart` ~64–65; collection gated by `AppConfig` | **Minor startup**; dev can disable collection |
| #353, #355 | Account/baby delete + `storage_cleanup_jobs` | API still runs **synchronous** SQL: collect all photo paths, `DELETE FROM baby_profiles` (CASCADE), insert job, then publish (`baby_profile_delete.py`, `account_delete_media.py`) | **Request-latency regression risk** for large babies (PERF-API-03) |
| #356–#358 | Shared confirm sheet | Modal UI only (`app_confirm_dialog.dart`) | **No measurable regression** |

Hard-delete migration **043** added `ON DELETE CASCADE` on `baby_profile_id` FKs without new indexes on referencing columns; existing child indexes (e.g. `idx_photos_baby_created`, `idx_activity_events_baby_created`) support cascade deletes. `notifications.baby_profile_id` now cascades (was `SET NULL` in 011).

---

## Ranked opportunities

Impact: **H** / **M** / **L**. Effort: **S** / **M** / **L**. Risk: **L** / **M** / **H** (change risk, not security).

| ID | Area | Finding | Evidence | Expected impact | Effort | Risk | Proposed fix (layer) |
|----|------|---------|----------|-----------------|--------|------|----------------------|
| PERF-API-01 | Infra / API | Cloud Run **concurrency not configured**; default (80) × `DB_POOL_MAX_SIZE` 5 can exhaust Cloud SQL connections under burst | `services/api/scripts/deploy.sh` sets CPU/memory/min/max only (~55–68); pool budget documented in `config.py` ~24–28 and `development.md` ~66 | **H** — pool timeouts, tail latency | S | M | Set `--concurrency` (e.g. 10–20) aligned with pool; document in `infra/env/*.api.env`; load-test |
| PERF-API-02 | API / DB | Gallery list runs **two correlated subqueries per row** (squish + comment counts) | `repositories/photos.py` ~77–81 inside `list_photos_for_baby`; used by `domain/gallery.py` `list_gallery` ~123–129 | **H** — p95 gallery list on large albums | M | L | SQL: lateral joins or pre-aggregated subselect grouped by `photo_id`; keep `read_scope()` |
| PERF-API-03 | API | **Baby/account delete** holds transaction while scanning photos + CASCADE delete | `baby_profile_delete.py` ~51–55 `collect_photo_storage_for_babies` + `hard_delete_baby_profiles`; `043_baby_hard_delete.sql` CASCADE | **H** for owners with 1k+ photos | M | M | Move path collection to background job or limit work in request (enqueue first, worker resolves GCS); keep SQL correctness |
| PERF-API-04 | API | **Photo detail** returns unbounded comment list | `list_photo_comments` ~222–235 no `LIMIT`; `get_photo_detail` ~162–183 | **M** — payload + JSON time on viral threads | S | L | Paginate comments API; mobile loads first page + “load more” |
| PERF-API-05 | API | **Home summary** remains multi-query (~9+ bounded reads) per call | `domain/home.py` `_build_home_summary` ~216–375; `build_home_summary` wraps `read_scope()` ~207–209 | **M** — CPU/DB time per home open | M | M | Optional materialized slice or fewer round-trips (single SQL function); trim `recent_activity` when client caches |
| PERF-API-06 | API | **Favorites gallery sort** embeds correlated squish filter | `list_photos_for_baby` ~55–64 `favorites_clause` | **M** on favorites tab | M | L | Rewrite with JOIN + `GROUP BY` / `HAVING` on indexed `photo_squishes` PK |
| PERF-API-07 | API | **`mark_all_notifications_read`** returns every updated id | `repositories/notifications.py` ~62–73 `RETURNING id` | **M** for power users with large inboxes | S | L | Return count only; client already uses `updated` int |
| PERF-API-08 | API | No **Cache-Control / ETag** on stable reads | No matches in `services/api`; gzip only in `main.py` ~55–80 | **L** now; **M** at scale | M | M | Short `private` max-age on baby list / static config; ETag on home-summary optional |
| PERF-API-09 | API | **Signed URL** work still scales with thumb count per page | Batch signing is fixed (`media_urls.py`); gallery still signs every thumb on each cache miss | **M** — IAM `signBlob` CPU | S | L | Already parallel; extend client disk TTL alignment (900s URL / 5m server reuse per `storage.py` doc) |
| PERF-API-10 | API | **Cold start** imports full router graph at import time | `main.py` ~22–39 router imports | **L** on dev (min-instances=1); **M** if scaled to zero | M | L | Lazy-import heavy routers or slim worker-only deps (worker already separate) |
| PERF-MOB-01 | Mobile | **Notifications inbox** fetches first page only (50), **no “load more”**; tap row refetches **entire** inbox | `notifications_repository.dart` ~220–223; `notifications_inbox_screen.dart` ~151–165 `_load()` after each tap | **M** — bandwidth + scroll jank for active users | M | L | Paginate with `offset`/`has_more`; optimistic read state without full reload |
| PERF-MOB-02 | Mobile | **Gallery upload** polls `fetchPhoto` up to **12 × 2s** | `gallery_screen.dart` ~282–291 `_pollUntilReady` | **M** — battery/network after upload | S | L | Push-driven refresh or exponential backoff + single in-flight poll; stop when tab hidden |
| PERF-MOB-03 | Mobile | **Shell** `context.watch<SelectedBabyStore>()` rebuilds top bar when selection changes | `shell_top_bar.dart` ~54 | **L** — extra rebuilds vs `select`/listenables | S | L | `ListenableBuilder` only on title field or `Selector` pattern |
| PERF-MOB-04 | Mobile | **Calendar** reloads full month + upcoming on **any** `CalendarRepository` mutation | `calendar_repository.dart` ~32–34 `_markEventsChanged`; `calendar_screen.dart` ~77 `_onEventsChanged` → `_load()` | **M** — redundant API when editing events | S | L | Narrow notify (month key) or merge into cache without full reload |
| PERF-MOB-05 | Mobile | **Biometric lock** cold path: account load + overlay `setState` | `biometric_app_lock.dart` ~151–161, ~177–196 | **L** one-time per session | S | L | Accept; optional prefetch account in `ShellChromeSync` (already loads account ~65–71) |
| PERF-MOB-06 | Mobile | **Non-virtualized lists** on heavy tabs (home, calendar, fun, registry, followers, …) | e.g. `home_screen.dart` ~256 `ListView(` children; `calendar_screen.dart` uses scroll views with many children; only `notifications_inbox_screen.dart` ~140 uses `ListView.builder` | **M** build/layout cost as sections grow | M | L | `ListView.builder` / slivers for long sections; keep home as few sections |
| PERF-MOB-07 | Mobile | **Photo detail** builds every comment widget | `photo_detail_screen.dart` ~738 `for (var i = 0; i < detail.comments.length; i++)` | **M** with long threads | M | L | ListView.builder for comments; tie to API pagination (PERF-API-04) |
| PERF-MOB-08 | Mobile | **FCM foreground** message triggers unread refetch | `push_notification_service.dart` ~70–71 → `notifyInboxMayHaveChanged` | **L–M** during notification storms | S | L | Debounce unread refresh (e.g. 2s) or increment local badge |
| PERF-MOB-09 | Mobile | **Dual gallery pagination state**: screen `_photos` vs repo `PhotoIdWindow` | `gallery_screen.dart` ~173–187 `listPhotosPage`; `gallery_repository.dart` ~67–78 `extendPhotoWindow` | **L** correctness/duplicate fetches for detail swipe | M | L | Single source: screen uses repo window for grid + detail |
| PERF-MOB-10 | Mobile | **APK size**: no **ABI splits**; all architectures in one APK | `android/app/build.gradle.kts` — no `splits { abi { ... } }`; R8 on release ~137–143 | **M** download size on Play | S | L | Enable ABI splits or App Bundle (Play default) |
| PERF-MOB-11 | Mobile | **Bundled fonts** + `google_fonts` package overhead | `pubspec.yaml` ~46, ~100 `assets/google_fonts/`; `app_fonts.dart` ~35–36 disables runtime fetch | **L** APK (~few MB) | M | L | Optional: declare fonts in `pubspec` `fonts:` and drop `google_fonts` dependency |
| PERF-MOB-12 | Mobile | **Provider** wide rebuilds: many screens use `setState` on large subtrees | Widespread `setState` in tab screens (e.g. `calendar_screen.dart` ~86–199) | **M** jank under load | M | L | Extract static subtrees `const`; localize state to sub-widgets |
| PERF-WKR-01 | Worker | **Storage cleanup sweep**: **10 jobs / 15 min**, sequential `run_storage_cleanup` | `storage_cleanup.py` ~23 `_SWEEP_BATCH = 10`; `setup-schedulers.sh` ~52–54 `*/15 * * * *` | **H** backlog after mass deletes | M | M | Raise batch, parallel workers per job with cap; paginate `list_blobs` + batch delete API |
| PERF-WKR-02 | Worker | **GCS prefix delete** lists then deletes **one object per RPC** | `gcs_delete.py` ~36–50 `list_blobs` + loop `delete_object` | **H** for large `exports/` trees | M | L | Batch delete / concurrency limit; continue treating 404 as success |
| PERF-WKR-03 | Worker | **Scale to zero** — cold start on Pub/Sub push | `deploy.sh` ~80 `--min-instances=0` | **M** tail latency first message after idle | S | L | `min-instances=1` for prod worker or min instances on push subscription tuning |
| PERF-WKR-04 | Worker | Fan-out notifications: DB + FCM in request handler | `notifications.py` `_FCM_MULTICAST_LIMIT = 500` | **M** under large babies | M | L | Already batched; monitor claim/retry storms (PERF-MEA-06) |
| PERF-INF-01 | Infra | **No CDN** in front of display/thumb buckets | `infra/terraform/modules/platform/storage.tf` — buckets only, no backend bucket / Cloud CDN | **M** image latency + egress at scale | L | M | Cloud CDN or signed cookie pattern; keep private buckets |
| PERF-INF-02 | Infra | **Co-location**: API, worker, SQL, buckets in `us-central1` (default) | `dev/main.tf` ~33 `region`; deploy scripts `GCP_REGION` | **L** today | S | L | Keep single region; document for multi-region future |
| PERF-INF-03 | Infra | Dev SQL **db-custom-1-3840** may need tuning under prod load | `infra/terraform/environments/dev/main.tf` ~40–42; prod uses `var.sql_tier` | **M** at growth | M | M | Query Insights-driven tier; read replicas only if needed |
| PERF-INF-04 | Infra | Prod API warm instance **cost vs latency** tradeoff documented | `prod.api.env` ~5–7 `API_MIN_INSTANCES=1` | **L** cost | S | L | Revisit after prod traffic metrics (PERF-MEA-01) |

---

## Needs measurement

Hypotheses that need runtime data before committing to implementation.

| ID | Hypothesis | Metric(s) to collect | Where / how |
|----|------------|----------------------|-------------|
| PERF-MEA-01 | API p95 latency is dominated by **home-summary** and **gallery list**, not cold start (dev min-instances=1) | Cloud Run request latency p50/p95 by route; CPU utilization | Cloud Monitoring, log-based metric on route template; compare `GET .../home-summary` vs `GET .../photos` |
| PERF-MEA-02 | Gallery SQL time grows **linearly with page size** due to per-row counts | Postgres Query Insights: mean time × calls for gallery list query; `EXPLAIN (ANALYZE, BUFFERS)` on staging with 500+ photos | Cloud SQL Query Insights; scripted `EXPLAIN` in staging |
| PERF-MEA-03 | **Baby delete** p95 exceeds product threshold when photo count > N | API latency histogram for `DELETE /v1/babies/{id}`; row counts from `photos` | Trace + DB count correlation per test baby |
| PERF-MEA-04 | Flutter **jank** on Calendar month change is from network, not layout | Frame timing (`flutter run --profile`, DevTools); network timeline parallel | Device lab: month swipe with 50+ events |
| PERF-MEA-05 | **Storage cleanup** queue depth grows after bulk account deletes | `storage_cleanup_jobs` count by `status`; age of oldest `pending` | SQL dashboard; log `storage_cleanup_sweep` `picked=` / `completed=` |
| PERF-MEA-06 | Worker **Pub/Sub retry storms** on failed cleanups | Pub/Sub `num_undelivered_messages`, delivery attempts, dead-letter counts | GCP Pub/Sub monitoring on `lanonna-async-commands` |
| PERF-MEA-07 | **Connection pool exhaustion** under load test | API logs `pool timeout`; Cloud SQL `num_backends`; Run concurrent requests | k6/locust against gallery + home with concurrency > pool × instances |
| PERF-MEA-08 | Mobile **gallery upload poll** causes measurable battery drain | Energy profiler; count of `fetchPhoto` per upload | Android Studio Energy; instrument test counting API calls |
| PERF-MEA-09 | **Inbox** users exceed 50 notifications | Distribution of inbox row counts per `firebase_uid` | One-off SQL `SELECT firebase_uid, COUNT(*) ...` (prod read replica) |
| PERF-MEA-10 | **APK download size** blocks low-storage installs | Release APK/AAB size per ABI; Play install failure rate | `flutter build appbundle`; Play Console |
| PERF-MEA-11 | **Image egress** cost dominates GCS bill | Egress GB by bucket; thumb vs display object access ratio | Cloud Billing export; bucket access logs sample |
| PERF-MEA-12 | **Biometric lock** adds >100 ms to cold start to interactive | `Time to first frame` with lock on/off | Firebase Performance custom trace or integration test |

---

## Quick reference — hot paths (evidence anchors)

**Mobile startup** — parallel App Check, bootstrap, fonts: `apps/mobile/lib/main.dart` ~41–45. App Check prefetch when signed in: `bootstrap.dart` ~66–68. Crashlytics: `bootstrap.dart` ~64–65.

**Mobile images** — network images funnel through `CachedSignedImage` → `DisplaySizedImage` (`cached_signed_image.dart` ~13–22). Gallery grid virtualizes via `SliverGrid.builder` (`gallery_photo_grid.dart` ~33–40).

**API read aggregation** — `read_scope()` pattern: `db.py` ~141–154; home: `domain/home.py` ~203–209; gallery list/detail: `domain/gallery.py` ~120–155.

**API connection budget** — `config.py` ~24–28; deploy max instances `infra/env/dev.api.env` ~9–12.

**Worker cleanup throughput** — batch 10, scheduler every 15 minutes: `storage_cleanup.py` ~23, ~131–159; `scripts/setup-schedulers.sh` ~52–54.

**Delete regressions (#355)** — synchronous SQL delete in API transaction before async GCS: `repositories/baby_profile_delete.py` ~51–55; async GCS in worker `storage_cleanup.py` ~96–128.

---

## Document history

| Date | Change |
|------|--------|
| 2026-10-23 | Initial audit (post #332–#338, regression pass #345–#358) |
