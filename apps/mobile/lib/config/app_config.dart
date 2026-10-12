/// Runtime config (dev defaults; override with --dart-define).
class AppConfig {
  const AppConfig._();

  /// True when the build passed `--dart-define=API_BASE_URL=...`.
  static bool get apiBaseUrlConfigured => bool.hasEnvironment('API_BASE_URL');

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-r27szgit5q-uc.a.run.app',
  );

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'hello@lanonna.app',
  );
}
