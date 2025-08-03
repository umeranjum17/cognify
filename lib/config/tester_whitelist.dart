// Tester whitelist configuration for internal access bypass
// Exact email matches only (case-insensitive). No domain-based wildcards in prod.
// Edit this list to add/remove testers.

class TesterWhitelistConfig {
  // Use exact emails only. Always lowercase them when comparing.
  static const List<String> testerEmails = <String>[
    // Initial tester
    'umeranjum17@gmail.com',
  ];
}

/// Helper to evaluate tester status based on email matching.
/// Comparison is case-insensitive and trims surrounding whitespace.
class TesterWhitelist {
  static bool isTesterEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final normalized = email.trim().toLowerCase();
    for (final allowed in TesterWhitelistConfig.testerEmails) {
      if (normalized == allowed.toLowerCase()) return true;
    }
    return false;
  }
}