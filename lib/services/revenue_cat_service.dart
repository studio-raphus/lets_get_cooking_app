// lib/services/revenue_cat_service.dart

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';

import '../secrets.dart';

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  static const String _apiKeyIOS = Secrets.revenueCatApiKey;
  static const String _apiKeyAndroid = Secrets.revenueCatApiKey;

  // Entitlement identifier from RevenueCat dashboard
  static const String entitlementID = 'Lets Get Cooking App Pro';

  Future<void> initialize(String userId) async {
    await Purchases.setLogLevel(LogLevel.debug); // Remove in production

    PurchasesConfiguration configuration;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      configuration = PurchasesConfiguration(_apiKeyIOS)..appUserID = userId;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      configuration = PurchasesConfiguration(_apiKeyAndroid)..appUserID = userId;
    } else {
      throw UnsupportedError('Platform not supported');
    }

    await Purchases.configure(configuration);

    // Optional: Set user attributes for analytics
    await Purchases.setAttributes({
      'signup_date': DateTime.now().toIso8601String(),
      'platform': defaultTargetPlatform.toString(),
    });
  }

  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  Future<bool> isPremium() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[entitlementID]?.isActive ?? false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  Future<Offerings?> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
      return null;
    }
  }

  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      PurchaseResult result = await Purchases.purchasePackage(package);
      return result.customerInfo;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('User cancelled purchase');
      } else if (errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
        debugPrint('Product already purchased');
      }
      return null;
    }
  }

  Future<CustomerInfo?> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return customerInfo;
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return null;
    }
  }

  // Track custom events for analytics
  void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    // You can integrate with your analytics platform here
    debugPrint('Event tracked: $eventName with properties: $properties');
  }

  void dispose() {
    // Clean up if needed
  }
}