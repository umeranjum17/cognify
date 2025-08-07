import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'lib/config/subscriptions_config.dart';
import 'lib/services/revenuecat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔧 Testing RevenueCat Configuration...');
  print('📱 Platform: ${defaultTargetPlatform}');
  print('🔑 API Key: ${SubscriptionsConfig.rcPublicKeyAndroid.substring(0, 10)}...');
  
  try {
    // Initialize RevenueCat
    await RevenueCatService.instance.initialize();
    
    print('✅ RevenueCat initialized successfully');
    print('🔧 Configured: ${RevenueCatService.instance.isConfigured}');
    
    // Try to get offerings
    final offerings = await RevenueCatService.instance.getOfferings();
    
    if (offerings == null) {
      print('❌ No offerings returned');
    } else {
      print('✅ Offerings found: ${offerings.all.length} total');
      print('📦 Current offering: ${offerings.current?.identifier ?? 'null'}');
      
      if (offerings.current != null) {
        print('📋 Available packages: ${offerings.current!.availablePackages.length}');
        for (final package in offerings.current!.availablePackages) {
          print('  - ${package.identifier}: ${package.storeProduct.title}');
        }
      }
    }
    
    // Try to get customer info
    final customerInfo = await Purchases.getCustomerInfo();
    print('👤 Customer info retrieved: ${customerInfo.originalAppUserId}');
    print('🎫 Entitlements: ${customerInfo.entitlements.active.keys.join(', ')}');
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('📚 Stack trace: $stackTrace');
  }
} 