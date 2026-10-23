# Store launch checklist (prod)

Use with [mobile-prod-flavor-and-crashlytics.md](../engineering/mobile-prod-flavor-and-crashlytics.md) and [operations.md](../engineering/operations.md).

## Firebase App Check (Android Play Integrity)

Before shipping a prod build with `APP_CHECK_ENFORCE=true`:

- [ ] In [Firebase Console](https://console.firebase.google.com/) → **lanonna-prod** → **App Check** → register the **Android** app with **Play Integrity**.
- [ ] Add the **upload key** and **Google Play app signing** certificate **SHA-256** fingerprints (from Play Console → Setup → App signing, and your upload keystore `keytool -list -v`).
- [ ] Link the Firebase Android app to the **Google Play** project (App Check → Play Integrity provider).
- [ ] Raise the App Check **token time-to-live** (e.g. **12–24 hours**) under App Check → Apps → your Android app → Settings, so cold starts do not re-attest on every process launch.
- [ ] Deploy API with `APP_CHECK_ENFORCE=true` ([`infra/env/prod.api.env`](../../infra/env/prod.api.env)); smoke-test a prod build from Play internal testing.

iOS prod uses **App Attest** (and DeviceCheck fallback per Firebase defaults); register the prod bundle id in App Check before enforce.

## Related

- [app-check-dev-release-play-integrity.md](../engineering/rca/app-check-dev-release-play-integrity.md)
- [pre-beta-qa.md](../engineering/pre-beta-qa.md)
