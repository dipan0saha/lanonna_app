/// Runtime config (dev defaults; override with --dart-define).
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-1008830071001.us-central1.run.app',
  );

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
}
