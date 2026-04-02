class AppConstants {
  static const String _baseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final baseUrl = _baseUrlFromEnv.trim();
    if (baseUrl.isNotEmpty) {
      return baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
    }

    throw StateError(
      'Missing API_BASE_URL. Create .env.json from .env.example.json and run '
      'Flutter with --dart-define-from-file=.env.json.',
    );
  }

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String usernameKey = 'username';
}
