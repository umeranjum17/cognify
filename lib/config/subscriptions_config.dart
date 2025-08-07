// Subscriptions configuration for RevenueCat integration
// TODO: Replace placeholders with real keys and product IDs once created in RevenueCat and the stores.

class SubscriptionsConfig {
  // RevenueCat public SDK keys (Environment: Production)
  // Get these from RevenueCat → Project → API Keys
  static const String rcPublicKeyAndroid = 'app9eb67f7e06';
  static const String rcPublicKeyIOS = 'TODO_REVENUECAT_PUBLIC_SDK_KEY_IOS';

  // Offering and entitlement identifiers
  static const String offeringDefault = 'default';
  static const String entitlementPremium = 'premium';

  // Product IDs (must match Google Play and App Store product identifiers)
  static const String productMonthly = 'premium_monthly';
  static const String productAnnual = 'premium_annual';

  // UI defaults
  static const bool annualDefaultOnPaywall = true; // Highlight annual by default
}