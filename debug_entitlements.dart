import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'lib/config/subscriptions_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔧 Debugging RevenueCat Entitlements...');
  print('📱 Platform: ${defaultTargetPlatform}');
  print('🔑 API Key: ${SubscriptionsConfig.rcPublicKeyAndroid.substring(0, 10)}...');
  print('🎯 Expected entitlement: "${SubscriptionsConfig.entitlementPremium}"');
  
  try {
    // Configure RevenueCat
    final apiKey = SubscriptionsConfig.rcPublicKeyAndroid;
    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
    
    print('✅ RevenueCat configured successfully');
    
    // Get customer info
    final customerInfo = await Purchases.getCustomerInfo();
    print('👤 Customer ID: ${customerInfo.originalAppUserId}');
    
    // Debug all entitlements
    print('\n🎫 ALL ENTITLEMENTS:');
    if (customerInfo.entitlements.all.isEmpty) {
      print('  ❌ No entitlements found at all');
    } else {
      print('  📊 Total entitlements: ${customerInfo.entitlements.all.length}');
      customerInfo.entitlements.all.forEach((key, entitlement) {
        final isActive = entitlement.isActive;
        final willRenew = entitlement.willRenew;
        final periodType = entitlement.periodType;
        final productIdentifier = entitlement.productIdentifier;
        
        print('    🏷️  "$key": ${isActive ? "✅ ACTIVE" : "❌ INACTIVE"}');
        print('       Product: $productIdentifier');
        print('       Period: $periodType');
        print('       Will renew: $willRenew');
        print('       Latest purchase: ${entitlement.latestPurchaseDate}');
        print('       Expires: ${entitlement.expirationDate}');
        print('');
      });
    }
    
    // Debug active entitlements specifically
    print('🎫 ACTIVE ENTITLEMENTS:');
    if (customerInfo.entitlements.active.isEmpty) {
      print('  ❌ No ACTIVE entitlements found');
    } else {
      print('  📊 Active entitlements: ${customerInfo.entitlements.active.length}');
      customerInfo.entitlements.active.keys.forEach((key) {
        print('    ✅ "$key"');
      });
    }
    
    // Check our specific entitlement
    print('\n🔍 CHECKING FOR "${SubscriptionsConfig.entitlementPremium}":');
    final hasExpectedEntitlement = customerInfo.entitlements.active.containsKey(SubscriptionsConfig.entitlementPremium);
    print('  Result: ${hasExpectedEntitlement ? "✅ FOUND" : "❌ NOT FOUND"}');
    
    // Check all purchases
    print('\n🛒 PURCHASES:');
    if (customerInfo.allPurchasedProductIdentifiers.isEmpty) {
      print('  ❌ No purchases found');
    } else {
      print('  📊 Total purchases: ${customerInfo.allPurchasedProductIdentifiers.length}');
      customerInfo.allPurchasedProductIdentifiers.forEach((productId) {
        print('    🛍️  "$productId"');
      });
    }
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('📚 Stack trace: $stackTrace');
  }
}