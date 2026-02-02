import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService extends ChangeNotifier {
  static const String premiumProductId = 'stirnraten_premium_499';
  static const String _entitlementKey = 'stirnraten_premium_unlocked_v1';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _initialized = false;
  bool _isPremium = false;
  bool _storeAvailable = false;
  bool _isLoading = false;
  bool _purchasePending = false;
  String? _lastError;
  List<ProductDetails> _products = <ProductDetails>[];

  bool get isPremium => _isPremium;
  bool get storeAvailable => _storeAvailable;
  bool get isLoading => _isLoading;
  bool get isPurchasePending => _purchasePending;
  String? get lastError => _lastError;
  ProductDetails? get premiumProduct =>
      _products.isNotEmpty ? _products.first : null;
  String get priceLabel => premiumProduct?.price ?? '4,99 €';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadCachedEntitlement();
    if (kIsWeb) return;
    _isLoading = true;
    notifyListeners();
    _storeAvailable = await _iap.isAvailable();
    if (_storeAvailable) {
      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          _lastError = error.toString();
          _purchasePending = false;
          notifyListeners();
        },
      );
      await _queryProducts();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCachedEntitlement() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_entitlementKey) ?? false;
    notifyListeners();
  }

  Future<void> _queryProducts() async {
    final response =
        await _iap.queryProductDetails({PurchaseService.premiumProductId});
    if (response.error != null) {
      _lastError = response.error!.message;
    }
    _products = response.productDetails;
  }

  Future<void> buyPremium() async {
    if (kIsWeb) {
      _lastError = 'In-app purchases are not supported on web.';
      notifyListeners();
      return;
    }
    if (!_storeAvailable) {
      _lastError = 'Store not available.';
      notifyListeners();
      return;
    }
    if (_products.isEmpty) {
      await _queryProducts();
    }
    final product = premiumProduct;
    if (product == null) {
      _lastError = 'Premium product not found.';
      notifyListeners();
      return;
    }
    _purchasePending = true;
    notifyListeners();
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    if (!_storeAvailable) {
      _lastError = 'Store not available.';
      notifyListeners();
      return;
    }
    _purchasePending = true;
    notifyListeners();
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          break;
        case PurchaseStatus.error:
          _purchasePending = false;
          _lastError = purchase.error?.message ?? 'Purchase failed.';
          break;
        case PurchaseStatus.canceled:
          _purchasePending = false;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _grantPremium();
          } else {
            _lastError = 'Purchase verification failed.';
          }
          _purchasePending = false;
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // TODO: Replace with server-side receipt validation for production use.
    return Future.value(true);
  }

  Future<void> _grantPremium() async {
    if (_isPremium) return;
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementKey, true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
