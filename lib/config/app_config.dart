class AppConfig {
  AppConfig._();

  static const webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://bscibd.com',
  );

  // Keep the API independent from the public website domain. The production
  // API can be moved with --dart-define once bscibd.com serves JSON under /api.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bsci.digitrixlabs.io/api',
  );
}
