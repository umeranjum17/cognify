/// Compile-time application secrets injected via --dart-define.
class AppSecrets {
  const AppSecrets._();

  /// Temporary hardcoded OpenRouter API key until secure storage is wired in.
  /// Replace with the real project key or inject via secrets manager.
  static const String openRouterApiKey = 'sk-openrouter-hardcoded-placeholder';

  /// Optional Brave Search key for search integrations.
  static const String braveSearchApiKey = String.fromEnvironment(
    'BRAVE_SEARCH_API_KEY',
    defaultValue: '',
  );

  /// Initial token allocation granted to a user on first login.
  static const int initialTokenAllocation = int.fromEnvironment(
    'INITIAL_TOKEN_ALLOCATION',
    defaultValue: 10,
  );
}
