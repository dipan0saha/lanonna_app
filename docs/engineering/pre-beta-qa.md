# Pre-beta QA runbook

Manual device checks before widening beta. Run against **lanonna-dev** with `flutter run --dart-define-from-file=flavors/dev.json`.

**Prerequisites**

- **Deploy / schema:** [operations.md](operations.md) — dev API + worker deployed; all SQL migrations applied on dev (`apply_migrations.py`; confirm with `./scripts/verify-dev-migrations.sh`).
- **App Check policy:** [`deploy.sh`](../../services/api/scripts/deploy.sh) defaults to **`APP_CHECK_ENFORCE=false`** on dev so sideloaded APKs work without registering every emulator token. The Flutter client still sends App Check when Firebase provides a token. Before wide beta, deploy with `APP_CHECK_ENFORCE=true ./services/api/scripts/deploy.sh` and register debug tokens (section 1 below). When enforce is off, the API accepts missing `X-Firebase-AppCheck` headers.
- **Beta gate script:** `./scripts/run-beta-gate.sh` runs unit tests and optionally deploys API. Force-update requires migration **`020_app_versions`** (covered by the migration gate).
- Firebase **App Check** enabled for Android/iOS. **Android (recommended):** `APP_CHECK_DEBUG_TOKEN` in `apps/mobile/maestro/local.env`, `./maestro/scripts/register-app-check-debug.sh`, rebuild debug — same UUID after `pm clear` / reinstall. Otherwise register from logcat (`Firebase App Check debug token: …`).
- Disable `DEV_AUTO_SIGN_IN_*` when testing unsigned invite UX.
- Second test account or follower membership for push fan-out tests.

## 1. App Check

- [ ] (Android dev) Pinned token: `APP_CHECK_DEBUG_TOKEN` in `maestro/local.env` + `register-app-check-debug.sh` + rebuild; logcat UUID matches pin after cold start (release builds ignore the pin).
- [ ] Signed-in home loads; debug logcat shows `Firebase App Check ready for API` when pinned/registered; API requests include `X-Firebase-AppCheck` when enforce is on.
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
  -d 'https://lanonna-dev.firebaseapp.com/invite?token=VALID_TOKEN'
```

Custom scheme still works: `lanonna://app/invite-accept?token=VALID_TOKEN`.

- [ ] Lands on invite accept / preview flow.
- [ ] The invite email link is `https://lanonna-dev.firebaseapp.com/invite?token=…`. With the app installed it opens the accept flow. Without the app, the page names the inviter and baby and explains install; it does not show the token in the page source beyond the address bar.
- [ ] Kill app; relaunch **without** link → stored `pendingInviteToken` resumes (see [development.md](development.md)).
- [ ] Accept while signed in as a **different** email → **Wrong account** shows both addresses; **Switch account** prefills login (no emails in the route URL).

## 7. Gallery comments and baby tags

Requires migration **`019`** on dev (`photo_baby_tags` — [migrations/README.md](../../infra/db/migrations/README.md)).

- [ ] Photo detail: edit and delete **own** comment; cannot edit others’ comments.
- [ ] Event detail: same for event comments.
- [ ] Photo detail (owner, multi-baby account): “In this photo” **AppToggleChip** pills tag/untag other babies you belong to; followers see read-only tag names when set.

## 8. Email verification (FR-AUTH-002)

Use a **real** inbox (not `@test.com` smoke addresses).

- [ ] Sign up with email/password → verify screen copy mentions **Verify my email** (no Google “skips verification” note on this screen).
- [ ] Email subject is **Verify your email for La Nonna** (not `project-1008830071001`), sender display name **La Nonna**, body is the branded template with **Verify my email**. Password reset uses **Reset your password for La Nonna**.
- [ ] Tap link → verified (in app or browser + **Continue**); user reaches complete profile.
- [ ] **Desktop:** after Firebase **Continue**, browser shows **Email verified** at `https://lanonna-dev.firebaseapp.com/email-verified` (not Hosting 404); then on phone tap **Continue** on Check your email.

## 9. Account delete (FR-SET-005)

Use a **throwaway** Firebase account (not Maestro smoke user).

- [ ] Sole owner of at least one baby: Profile → Delete account shows FR-SET-005 confirmation copy; **Delete my account** is enabled; confirm → signed out to onboarding; baby no longer listed for any member.
- [ ] Co-owner on a baby: deleting one owner leaves baby visible to the other owner (ownership unchanged aside from removed co-owner).

## 10. Search, export, and co-owner invites

- [ ] Search (magnifier in the top bar): a query that matches a **name suggestion** returns results (no error banner); photo captions, events, and registry items also appear.
- [ ] My Account → **Export baby data** (owner): job reaches **ready** and **Download export** works. Open the JSON: comments, RSVPs, members (display names, no member emails), predictions, announcement, photo tags, and registry purchases are present; photo `download_url` values are `https://` and note a 7-day expiry. Check `lanonna-async-commands-dlq-pull` is empty afterward ([operations.md](operations.md#dead-letter-queue)).
- [ ] Invite a second co-owner and accept → success; invite a **third** co-owner → "max owners" message, no extra membership.

## 11. Biometric unlock (M-31)

- [ ] Settings → enable biometric unlock (device must have biometrics enrolled); successful local auth required to turn on.
- [ ] Kill app with an active Firebase session and completed onboarding → app lock overlay on resume (no GoRouter crash on first frame); unlock with biometrics.
- [ ] Toggle off in Settings → no lock on next resume.

## 12. Onboarding UI (carousel, pills, chips)

- [ ] Owner/follower welcome carousels: art + caption band + dots; **Next** advances (prototype layout).
- [ ] Complete profile: optional **Mother** / **Father** equal-width pills; create-baby gender uses wrap pills.
- [ ] Owner flow: after create-baby + first moment, **Back** from first moment reopens create-baby in **revise** mode; save updates baby via PATCH (no duplicate POST).
- [ ] Subpage horizontal inset matches home tabs (~26px): e.g. Announce Arrival create vs registry shipping address.
- [ ] Profile photo: circle + grey **Add a photo** / **Change photo** caption (onboarding, create baby, first moment, edits).
- [ ] First moment: preset **+** pills (sage when selected); name suggestion tags removable (peach girl / sage boy).
- [ ] Event RSVP, AI suggestion tabs, followers role badge, announcement comment count use core chips (not Material black chips).

## 13. Regression smoke

- [ ] `flutter test`, API `pytest`, and worker `pytest` green (see [development.md](development.md#automated-tests)); `verify-dev-prerequisites.sh` includes `check-no-material-chips.sh`.
- [ ] Optional: `flutter build apk --release --dart-define-from-file=flavors/dev.json` (R8 shrink) installs and launches on a device.
- [ ] Optional: `flutter test integration_test/home_summary_load_test.dart` on emulator.
- [ ] Owner onboarding + gallery + calendar still usable.

Record date, device/emulator ID, and tester in your release notes when all boxes pass.

---

## Run log (template)

| Step | Result | Notes |
|------|--------|--------|
| API deploy | | Revision from `gcloud run services describe api --region=us-central1`; URL from `flavors/dev.json` |
| `APP_CHECK_ENFORCE` | | Dev default **false** in `deploy.sh`; set **true** + debug tokens before wide beta |
| Migrations | | `apply_migrations.py` + `verify-dev-migrations.sh` via Cloud SQL proxy |
| App Check debug token | | `maestro/local.env` + `register-app-check-debug.sh`, or Firebase Console / CLI |
| Invite cold start (adb) | | Needs valid pending invite token |
| Push / encode / cache / tags | Manual | Second member account for fan-out |

**Emulator note:** If `INSTALL_FAILED_INSUFFICIENT_STORAGE`, run `adb shell pm trim-caches 500M` and reinstall APK.
