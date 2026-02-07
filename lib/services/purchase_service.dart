import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService extends ChangeNotifier {
  static const String premiumProductId = 'stirnraten_premium_499';
  static const String _productIdsRaw = String.fromEnvironment(
    'IAP_PRODUCT_IDS',
    defaultValue: premiumProductId,
  );
  static const String _verificationEndpoint = String.fromEnvironment(
    'IAP_VERIFICATION_ENDPOINT',
    defaultValue: '',
  );
  static const String _entitlementKey = 'stirnraten_premium_unlocked_v1';

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final List<String> _configuredProductIds = _parseConfiguredProductIds(
    _productIdsRaw,
  );

  bool _initialized = false;
  bool _isPremium = false;
  bool _storeAvailable = false;
  bool _isLoading = false;
  bool _purchasePending = false;
  String? _lastError;
  List<ProductDetails> _products = <ProductDetails>[];
  List<String> _notFoundProductIds = <String>[];

  bool get isPremium => _isPremium;
  bool get storeAvailable => _storeAvailable;
  bool get isLoading => _isLoading;
  bool get isPurchasePending => _purchasePending;
  String? get lastError => _lastError;
  List<String> get configuredProductIds =>
      List.unmodifiable(_configuredProductIds);
  List<String> get notFoundProductIds => List.unmodifiable(_notFoundProductIds);
  ProductDetails? get premiumProduct {
    if (_products.isEmpty) return null;
    for (final productId in _configuredProductIds) {
      for (final product in _products) {
        if (product.id == productId) {
          return product;
        }
      }
    }
    return _products.first;
  }

  String get priceLabel => premiumProduct?.price ?? '4,99 €';
  bool get debugUnlockAvailable => kDebugMode;

  PurchaseService({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  static List<String> _parseConfiguredProductIds(String raw) {
    final parts = raw
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return <String>[premiumProductId];
    }
    return parts.toSet().toList(growable: false);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadCachedEntitlement();
    if (kIsWeb) {
      _lastError = 'In-App-Käufe werden im Web nicht unterstützt.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
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
      } else {
        _products = <ProductDetails>[];
        _notFoundProductIds = <String>[];
        _lastError =
            'App Store ist auf diesem Gerät oder Account nicht verfügbar.';
      }
    } catch (error) {
      _lastError = 'App-Store-Initialisierung fehlgeschlagen: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCachedEntitlement() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_entitlementKey) ?? false;
    notifyListeners();
  }

  Future<void> _queryProducts() async {
    final response =
        await _iap.queryProductDetails(_configuredProductIds.toSet());
    _notFoundProductIds = response.notFoundIDs;
    if (response.error != null) {
      _lastError = response.error!.message;
    }
    _products = response.productDetails;
    if (_products.isEmpty && response.error == null) {
      _lastError = _missingProductMessage();
    } else if (_products.isNotEmpty && response.error == null) {
      _lastError = null;
    }
  }

  Future<void> refreshProducts() async {
    if (kIsWeb) return;
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) {
        _products = <ProductDetails>[];
        _notFoundProductIds = <String>[];
        _lastError =
            'App Store ist auf diesem Gerät oder Account nicht verfügbar.';
        return;
      }
      await _queryProducts();
    } catch (error) {
      _lastError = 'Produkte konnten nicht aktualisiert werden: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> buyPremium() async {
    _lastError = null;
    if (kIsWeb) {
      _lastError = 'In-App-Käufe werden im Web nicht unterstützt.';
      notifyListeners();
      return;
    }
    if (!_storeAvailable || _products.isEmpty) {
      await refreshProducts();
    }
    if (!_storeAvailable) {
      _lastError = 'App Store nicht verfügbar.';
      notifyListeners();
      return;
    }
    final product = premiumProduct;
    if (product == null) {
      _lastError = _missingProductMessage();
      notifyListeners();
      return;
    }
    try {
      _purchasePending = true;
      notifyListeners();
      final purchaseParam = PurchaseParam(productDetails: product);
      final launched =
          await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!launched) {
        _purchasePending = false;
        _lastError = 'Der Kaufdialog konnte nicht geöffnet werden.';
        notifyListeners();
      }
    } catch (error) {
      _purchasePending = false;
      _lastError = 'Kauf fehlgeschlagen: $error';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    _lastError = null;
    if (kIsWeb) {
      _lastError = 'In-App-Käufe werden im Web nicht unterstützt.';
      notifyListeners();
      return;
    }
    if (!_storeAvailable) {
      await refreshProducts();
    }
    if (!_storeAvailable) {
      _lastError = 'App Store nicht verfügbar.';
      notifyListeners();
      return;
    }
    try {
      _purchasePending = true;
      notifyListeners();
      await _iap.restorePurchases();
    } catch (error) {
      _purchasePending = false;
      _lastError = 'Wiederherstellen fehlgeschlagen: $error';
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      final isConfiguredProduct =
          _configuredProductIds.contains(purchase.productID);
      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (isConfiguredProduct) {
            _purchasePending = true;
          }
          break;
        case PurchaseStatus.error:
          if (isConfiguredProduct) {
            _purchasePending = false;
            _lastError = purchase.error?.message ?? 'Kauf fehlgeschlagen.';
          }
          break;
        case PurchaseStatus.canceled:
          if (isConfiguredProduct) {
            _purchasePending = false;
            _lastError = 'Kauf abgebrochen.';
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (!isConfiguredProduct) {
            break;
          }
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _grantPremium();
            _lastError = null;
          } else {
            _lastError = 'Kaufprüfung fehlgeschlagen.';
          }
          _purchasePending = false;
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    final hasPendingConfiguredPurchase = purchases.any(
      (purchase) =>
          _configuredProductIds.contains(purchase.productID) &&
          purchase.status == PurchaseStatus.pending,
    );
    if (!hasPendingConfiguredPurchase) {
      _purchasePending = false;
    }
    notifyListeners();
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    if (!_configuredProductIds.contains(purchase.productID)) {
      return false;
    }
    final verificationData = purchase.verificationData.serverVerificationData;
    final localVerificationData =
        purchase.verificationData.localVerificationData;
    if (verificationData.isEmpty && localVerificationData.isEmpty) {
      return false;
    }

    final endpoint = _verificationEndpoint.trim();
    if (endpoint.isEmpty) {
      // Client-only fallback for local testing; production should use server verification.
      return true;
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || (!uri.hasScheme || uri.host.isEmpty)) {
      _lastError = 'Ungültiger Verifizierungs-Endpunkt.';
      return false;
    }

    try {
      final response = await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'productId': purchase.productID,
              'purchaseId': purchase.purchaseID,
              'transactionDate': purchase.transactionDate,
              'source': purchase.verificationData.source,
              'serverVerificationData': verificationData,
              'localVerificationData': localVerificationData,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError =
            'Verifizierungsserver lieferte HTTP ${response.statusCode}.';
        return false;
      }

      final parsed = jsonDecode(response.body);
      if (parsed is! Map<String, dynamic>) {
        _lastError = 'Verifizierungsserver lieferte eine ungültige Antwort.';
        return false;
      }
      final valid = parsed['valid'] == true;
      if (!valid && parsed['message'] is String) {
        _lastError = parsed['message'] as String;
      }
      return valid;
    } catch (error) {
      _lastError = 'Kauf konnte nicht verifiziert werden: $error';
      return false;
    }
  }

  Future<void> _grantPremium() async {
    if (_isPremium) return;
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementKey, true);
  }

  Future<void> unlockPremiumForDebug() async {
    if (!kDebugMode) return;
    await _grantPremium();
    _lastError = null;
    notifyListeners();
  }

  String _missingProductMessage() {
    final configured = _configuredProductIds.join(', ');
    if (_notFoundProductIds.isNotEmpty) {
      return 'Premium-Produkt im App Store nicht gefunden. Konfigurierte IDs: '
          '$configured. Nicht gefunden: ${_notFoundProductIds.join(', ')}';
    }
    return 'Premium-Produkt im App Store nicht gefunden. Konfigurierte IDs: '
        '$configured';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
