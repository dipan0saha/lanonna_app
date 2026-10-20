# Android build notes

## Upload keystore (Play release)

Prod release builds (`APP_ENV=prod` via `flavors/prod.json`) **require** `android/key.properties`. Dev release builds may still use the debug keystore when `key.properties` is absent.

1. Create an upload keystore (once per app signing identity):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Store the `.jks` outside the repo (password manager + secure backup).

2. Copy `key.properties.example` to `key.properties` and set `storeFile` to the absolute path of the keystore.

3. Build prod with `flutter build appbundle --dart-define-from-file=flavors/prod.json` after filling prod placeholders and Firebase config (see [mobile-prod-flavor-and-crashlytics.md](../../../docs/engineering/mobile-prod-flavor-and-crashlytics.md)).

## App Link host

`AndroidManifest.xml` uses `manifestPlaceholders` `appLinkHost`, set from Flutter `dart-defines` (`APP_LINK_HOST` in the flavor JSON). Default when unset: `lanonna-dev.firebaseapp.com`.
