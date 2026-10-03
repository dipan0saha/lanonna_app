# Pre-beta QA runbook

Manual device checks before widening beta. Run against **lanonna-dev** with `flutter run --dart-define-from-file=flavors/dev.json`.

**Prerequisites**

- Cloud Run `api` deployed with `APP_CHECK_ENFORCE=true` (see `services/api/scripts/deploy.sh`).
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

## 3. Image disk cache

- [ ] Open gallery feed; scroll away and back — thumbs load from cache (no full-screen spinner on every revisit).
- [ ] Photo detail display image similarly fast on second open.

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

## 7. Regression smoke

- [ ] `flutter test` and API `pytest` green.
- [ ] Owner onboarding + gallery + calendar still usable.

Record date, device/emulator ID, and tester in your release notes when all boxes pass.

---

## Run log (2026-10-03, agent)

| Step | Result | Notes |
|------|--------|--------|
| API deploy | Pass | `api-00029-vxl`; `APP_CHECK_ENFORCE=true`; URL `https://api-r27szgit5q-uc.a.run.app` |
| App Check debug token | Pass | Registered via Firebase CLI 15.x: `firebase appcheck:debugtokens:create …` (emulator `emulator-5554`) |
| App Check JWT | Pass | After registration, Flutter logs App Check JWT (no 403 exchange error) |
| Public invite preview | Pass | `GET /v1/invitations/preview` returns 404 without App Check (expected for bad token) |
| Protected route | Pass | `GET /v1/me` without auth → 401 |
| Invite cold start (adb) | Partial | `adb shell am start -a VIEW -d 'lanonna://app/invite-accept?token=…'` launches app; full flow needs a **valid** pending invite token from email/Mailjet |
| Push / encode / cache | Manual | Sign in on emulator, upload photo, second account push — complete locally using smoke user in [development.md](development.md) |

**Emulator note:** If `INSTALL_FAILED_INSUFFICIENT_STORAGE`, run `adb shell pm trim-caches 500M` and reinstall APK.

**CLI:** Upgrade Firebase tools (`npm i -g firebase-tools@latest`) so `appcheck:debugtokens:create` is available.
