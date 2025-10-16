// Purchases configuration for RevenueCat consumables (credit-based system)

class PurchasesConfig {
  // Global flag for enabling RevenueCat consumable purchases.
  static const bool purchasesEnabled = true;

  // RevenueCat public SDK keys (Environment: Production)
  static const String rcPublicKeyAndroid = 'goog_bPnaGqdwHbhqoOYLYupZBaPWySp';
  static const String rcPublicKeyIOS = 'appl_YEqixFmxSRzmfBQeDEzEVrdHzfa';

  // Offering identifiers (optional but commonly used)
  static const String offeringDefault = 'default';

  // Product IDs (must match Google Play and App Store product identifiers)
  static const String productCredits500 = 'com.cognify.credits.500';
  static const String productMonthly = 'premium_monthly';
  static const String productAnnual = 'premium_annual';
}


