import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenue_cat_service.dart';

class PremiumProvider with ChangeNotifier {
  final RevenueCatService _revenueCat = RevenueCatService();

  bool _isPremium = false;
  bool _isLoading = false;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  bool _isRevenueCatConfigured = false;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  Offerings? get offerings => _offerings;
  CustomerInfo? get customerInfo => _customerInfo;
  bool get isRevenueCatConfigured => _isRevenueCatConfigured;

  // Feature limits for free tier
  static const int freeRecipeLimit = 10;
  static const int freeGroceryListsLimit = 3;

  Future<void> initialize(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _revenueCat.initialize(userId);
      _isRevenueCatConfigured = true;

      await checkPremiumStatus();
      await loadOfferings();
    } catch (e) {
      _isPremium = false;
      _isRevenueCatConfigured = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkPremiumStatus() async {
    try {
      _customerInfo = await _revenueCat.getCustomerInfo();
      _isPremium = _customerInfo?.entitlements
          .all[RevenueCatService.entitlementID]?.isActive ?? false;

      notifyListeners();
    } catch (e) {
      _isPremium = false;
    }
  }

  Future<void> loadOfferings() async {
    try {
      _offerings = await _revenueCat.getOfferings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading offerings: $e');
    }
  }

  Future<bool> purchasePackage(Package package) async {
    _isLoading = true;
    notifyListeners();

    try {
      CustomerInfo? customerInfo = await _revenueCat.purchasePackage(package);
      if (customerInfo != null) {
        _customerInfo = customerInfo;
        _isPremium = customerInfo.entitlements
            .all[RevenueCatService.entitlementID]?.isActive ?? false;

        if (_isPremium) {
          _revenueCat.trackEvent('premium_purchased', properties: {
            'package_id': package.identifier,
            'price': package.storeProduct.priceString,
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restorePurchases() async {
    _isLoading = true;
    notifyListeners();

    try {
      CustomerInfo? customerInfo = await _revenueCat.restorePurchases();
      if (customerInfo != null) {
        _customerInfo = customerInfo;
        _isPremium = customerInfo.entitlements
            .all[RevenueCatService.entitlementID]?.isActive ?? false;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Feature gate helpers
  bool canAddMoreRecipes(int currentRecipeCount) {
    if (_isPremium) return true;
    return currentRecipeCount < freeRecipeLimit;
  }

  bool canUseAIImport() => _isPremium;
  bool canUseMealPlanning() => _isPremium;
  bool canUseVideoExtraction() => _isPremium;
  bool canCreateCollections() => _isPremium;
}