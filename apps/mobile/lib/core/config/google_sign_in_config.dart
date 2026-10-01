/// Web OAuth client ID (client_type 3 from google-services.json).
/// Set via --dart-define-from-file=flavors/dev.json after enabling Google in Firebase.
abstract final class GoogleSignInConfig {
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static String? get optionalServerClientId =>
      serverClientId.isEmpty ? null : serverClientId;
}
