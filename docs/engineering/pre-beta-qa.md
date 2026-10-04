# Pre-beta QA runbook

Manual device checks before widening beta. Run against **lanonna-dev** with `flutter run --dart-define-from-file=flavors/dev.json`.

**Prerequisites**

- **App Check policy:** [`deploy.sh`](../../services/api/scripts/deploy.sh) defaults to **`APP_CHECK_ENFORCE=false`** on dev so sideloaded APKs work without registering every emulator token. The Flutter client still sends App Check when Firebase provides a token. Before wide beta, deploy with `APP_CHECK_ENFORCE=true ./services/api/scripts/deploy.sh` and register debug tokens (section 1 below). When enforce is off, the API accepts missing `X-Firebase-AppCheck` headers.
- **Beta gate script:** `./scripts/run-beta-gate.sh` runs unit tests and optionally deploys API. After deploy, apply migration **`020_app_versions`** on dev SQL so `GET /v1/app/version` and force-update work.
- Firebase **App Check** enabled for Android/iOS; **debug token** registered for your emulator (log line on app start: `Firebase App Check debug token …`).
- Disable `DEV_AUTO_SIGN_IN_*` when testing unsigned invite UX.
- Second test account or follower membership for push fan-out tests.

## 1. App Check

- [ ] Cold start app; logcat shows App Check debug token; token added under Firebase Console → App Check → Apps → Manage debug tokens.
- [ ] Signed-in home loads (API calls include `X-Firebase-AppCheck`).
- [ ] `GET /v1/invitations/preview?token=…` still works **without** App Check (public invite landing).

## 2. Display encode (FR-GAL-002)

- [ ] Gallery upload a large camera photo; completes without “exceeds maximum size”.
- [ ] Cloud SQL `photos.byte_length` (or GCS object size) ≤ 2 MB; feed shows thumb after worker processes.

## 3. Image disk cache and signed URLs

- [ ] Open gallery feed; scroll away and back — thumbs load from cache (no full-screen spinner on every revisit).
- [ ] Photo detail display image similarly fast on second open.
- [ ] After **15+ minutes** on home (or forced stale thumb), teaser thumbs recover after pull-to-refresh or automatic `onSignedUrlError` retry (900s signed URL TTL).

## 4. Push notifications (realtime)

- [ ] User A: `notification_digest=realtime`, push enabled, gallery channel on.
- [ ] User B (member): upload photo → A receives FCM.
- [ ] Tap notification → correct screen (`/gallery/photo/{id}` or inbox deep link).

## 5. In-app deep links

- [ ] Notification inbox row opens target route.
- [ ] Home teaser photo → gallery detail.
- [ ] Paths `/settings`, `/calendar/event/{id}` work from `normalizeAppDeepLinkPath`.

## 6. Invite cold start

Kill app first (`adb shell am force-stop com.lanonna.lanonna`).

```bash
adb shell am start -a android.intent.action.VIEW \
  -d 'lanonna://app/invite-accept?token=VALID_TOKEN'
```

- [ ] Lands on invite accept / preview flow.
- [ ] Kill app; relaunch **without** link → stored `pendingInviteToken` resumes (see [development.md](development.md)).

## 7. Gallery comments and baby tags

Requires migration **`019`** on dev (`photo_baby_tags` — [migrations/README.md](../../infra/db/migrations/README.md)).

- [ ] Photo detail: edit and delete **own** comment; cannot edit others’ comments.
- [ ] Event detail: same for event comments.
- [ ] Photo detail (owner, multi-baby account): “In this photo” chips tag/untag other babies you belong to; followers see read-only tag names when set.

## 8. Regression smoke

- [ ] `flutter test` and API `pytest` green (`services/api/.venv/bin/pytest -q`).
- [ ] Optional: `flutter test integration_test/home_summary_load_test.dart` on emulator.
- [ ] Owner onboarding + gallery + calendar still usable.

Record date, device/emulator ID, and tester in your release notes when all boxes pass.

---

## Run log (template)

| Step | Result | Notes |
|------|--------|--------|
| API deploy | | Revision from `gcloud run services describe api --region=us-central1`; URL from `flavors/dev.json` |
| `APP_CHECK_ENFORCE` | | Dev default **false** in `deploy.sh`; set **true** + debug tokens before wide beta |
| Migration `019` | | `apply_migrations.py` via Cloud SQL proxy |
| App Check debug token | | Firebase Console or `firebase appcheck:debugtokens:create` |
| Invite cold start (adb) | | Needs valid pending invite token |
| Push / encode / cache / tags | Manual | Second member account for fan-out |

**Emulator note:** If `INSTALL_FAILED_INSUFFICIENT_STORAGE`, run `adb shell pm trim-caches 500M` and reinstall APK.
