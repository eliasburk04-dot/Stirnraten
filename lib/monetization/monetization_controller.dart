import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_usage_snapshot.dart';
import 'berlin_date.dart';
import 'daily_quota.dart';
import 'monetization_limits.dart';
import 'monetization_prefs.dart';

abstract class MonetizationIapClient {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases({String? applicationUserName});
  Future<void> completePurchase(PurchaseDetails purchase);
}

class StoreMonetizationIapClient implements MonetizationIapClient {
  final InAppPurchase _iap;

  StoreMonetizationIapClient(this._iap);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _iap.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      _iap.restorePurchases(applicationUserName: applicationUserName);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}

abstract class PremiumSyncClient {
  Future<bool> verifyAndSync({
    required String platform,
    required String productId,
    required String verificationData,
  });
}

class SupabasePremiumSyncClient implements PremiumSyncClient {
  const SupabasePremiumSyncClient();

  @override
  Future<bool> verifyAndSync({
    required String platform,
    required String productId,
    required String verificationData,
  }) async {
    try {
      final sb = Supabase.instance.client;
      final res = await sb.functions.invoke(
        'verify-premium',
        body: <String, dynamic>{
          'platform': platform,
          'productId': productId,
          'verificationData': verificationData,
        },
      );
      final data = res.data;
      return data is Map && data['premium'] == true;
    } catch (_) {
      return false;
    }
  }
}

abstract class IosReceiptClient {
  Future<String?> refreshServerVerificationData();
}

class StoreKitIosReceiptClient implements IosReceiptClient {
  const StoreKitIosReceiptClient();

  @override
  Future<String?> refreshServerVerificationData() async {
    try {
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      try {
        // StoreKit 2 sync; safe to ignore on older setups.
        await addition.sync();
      } catch (_) {
        // ignore
      }
      final verificationData = await addition.refreshPurchaseVerificationData();
      final receipt = verificationData?.serverVerificationData.trim();
      if (receipt == null || receipt.isEmpty) return null;
      return receipt;
    } catch (_) {
      return null;
    }
  }
}

class MonetizationController extends ChangeNotifier {
  static const String _envIosProductId =
      String.fromEnvironment('IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID');
  static const String _envAndroidProductId =
      String.fromEnvironment('ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID');
  static const String _fallbackIosProductId =
      'com.stirnraten.app.premium_lifetime';
  static const bool _forcePremiumInDebug =
      bool.fromEnvironment('FORCE_PREMIUM_DEBUG', defaultValue: false);

  final MonetizationPrefs _prefs;
  final MonetizationIapClient _iapClient;
  final PremiumSyncClient _premiumSyncClient;
  final IosReceiptClient _iosReceiptClient;

  bool _initialized = false;
  bool _iapConfigured = false;

  bool _isPremium = false;
  int _dailyAiGenerationsUsed = 0;
  String _dailyAiGenerationsDateKey = '';

  bool _purchaseBusy = false;
  String? _iapStatusMessage;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  ProductDetails? _premiumProduct;

  MonetizationController({
    MonetizationPrefs? prefs,
    MonetizationIapClient? iapClient,
    PremiumSyncClient? premiumSyncClient,
    IosReceiptClient? iosReceiptClient,
  })  : _prefs = prefs ?? MonetizationPrefs(),
        _iapClient =
            iapClient ?? StoreMonetizationIapClient(InAppPurchase.instance),
        _premiumSyncClient =
            premiumSyncClient ?? const SupabasePremiumSyncClient(),
        _iosReceiptClient =
            iosReceiptClient ?? const StoreKitIosReceiptClient();

  bool get isInitialized => _initialized;
  bool get isPremium => _isPremium;
  int get dailyAiGenerationsUsed => _dailyAiGenerationsUsed;
  String get dailyAiGenerationsDateKey => _dailyAiGenerationsDateKey;

  int get maxWordsPerList =>
      MonetizationLimits.maxWordsPerList(isPremium: _isPremium);

  bool get isPurchaseBusy => _purchaseBusy;
  bool get iapConfigured => _iapConfigured;
  String? get iapStatusMessage => _iapStatusMessage;
  bool get canAttemptPurchase => currentLifetimeProductId != null;
  bool get _isPremiumForcedForDebug => kDebugMode && _forcePremiumInDebug;

  String? get currentLifetimeProductId {
    final ios = _envIosProductId.trim();
    final android = _envAndroidProductId.trim();

    if (kIsWeb) {
      // No in-app purchases on web. Keep null to avoid purchase entry points.
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        // iOS is our current priority; keep a safe fallback to avoid "dead" premium UI.
        return ios.isEmpty ? _fallbackIosProductId : ios;
      case TargetPlatform.android:
        return android.isEmpty ? null : android;
      default:
        return null;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    BerlinDate.ensureInitialized();

    final todayKey = BerlinDate.dateKey();
    final snapshot = await _prefs.load(defaultDateKey: todayKey);
    _isPremium = snapshot.isPremium;
    if (_isPremiumForcedForDebug) {
      _isPremium = true;
    }
    _dailyAiGenerationsUsed = snapshot.dailyAiUsed;
    _dailyAiGenerationsDateKey = snapshot.dailyAiDateKey;
    _resetDailyQuotaIfNeeded();

    await _configureIapIfPossible();

    _initialized = true;
    if (_isPremiumForcedForDebug) {
      await _prefs.savePremium(true);
    }
    notifyListeners();
  }

  void _resetDailyQuotaIfNeeded() {
    final todayKey = BerlinDate.dateKey();
    final normalized = DailyQuota.normalize(
      storedDateKey: _dailyAiGenerationsDateKey,
      storedUsed: _dailyAiGenerationsUsed,
      todayKey: todayKey,
    );
    if (normalized.dateKey != _dailyAiGenerationsDateKey ||
        normalized.used != _dailyAiGenerationsUsed) {
      _dailyAiGenerationsDateKey = normalized.dateKey;
      _dailyAiGenerationsUsed = normalized.used;
      unawaited(
        _prefs.saveDailyAiUsage(
          used: _dailyAiGenerationsUsed,
          dateKey: _dailyAiGenerationsDateKey,
        ),
      );
    }
  }

  AiUsageSnapshot localAiUsageToday() {
    _resetDailyQuotaIfNeeded();
    return AiUsageSnapshot(
      dateKey: _dailyAiGenerationsDateKey,
      used: _dailyAiGenerationsUsed,
      limit: MonetizationLimits.freeDailyAiGenerations,
    );
  }

  bool canStartAiGenerationLocally() {
    _resetDailyQuotaIfNeeded();
    if (_isPremium) return true;
    return _dailyAiGenerationsUsed < MonetizationLimits.freeDailyAiGenerations;
  }

  Future<void> applyServerAiUsage(AiUsageSnapshot snapshot) async {
    if (_isPremiumForcedForDebug) {
      _isPremium = true;
      await _prefs.savePremium(true);
    } else if (snapshot.isPremium != null && snapshot.isPremium != _isPremium) {
      final serverPremium = snapshot.isPremium!;
      // Trust the server's premium status. If the server says "not premium",
      // downgrade locally — the old behaviour of always preserving local premium
      // caused phantom-premium on simulators/devices with stale SharedPreferences.
      _isPremium = serverPremium;
      await _prefs.savePremium(_isPremium);
    }
    _dailyAiGenerationsDateKey = snapshot.dateKey;
    _dailyAiGenerationsUsed = snapshot.used;
    await _prefs.saveDailyAiUsage(
      used: _dailyAiGenerationsUsed,
      dateKey: _dailyAiGenerationsDateKey,
    );
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    if (_isPremiumForcedForDebug && !value) return;
    if (_isPremium == value) return;
    _isPremium = value;
    await _prefs.savePremium(value);
    notifyListeners();
  }

  Future<void> _configureIapIfPossible({bool exposeErrors = false}) async {
    final productId = currentLifetimeProductId;
    if (productId == null) {
      _iapConfigured = false;
      if (exposeErrors) {
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android)) {
          _iapStatusMessage = defaultTargetPlatform == TargetPlatform.iOS
              ? 'IAP Produkt-ID fehlt. Setze IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID.'
              : 'IAP Produkt-ID fehlt.';
        } else {
          _iapStatusMessage =
              'Käufe sind auf dieser Plattform nicht verfügbar.';
        }
      } else {
        _iapStatusMessage = null;
      }
      return;
    }

    try {
      final available = await _iapClient.isAvailable();
      if (!available) {
        _iapConfigured = false;
        _iapStatusMessage = exposeErrors ? 'Store nicht verfügbar.' : null;
        return;
      }

      _purchaseSub?.cancel();
      _purchaseSub = _iapClient.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (_) {},
      );

      final details = await _iapClient.queryProductDetails(<String>{productId});
      if (details.error != null) {
        _iapConfigured = false;
        _iapStatusMessage =
            exposeErrors ? 'Produktabfrage fehlgeschlagen.' : null;
        return;
      }
      _premiumProduct =
          details.productDetails.isEmpty ? null : details.productDetails.first;

      _iapConfigured = _premiumProduct != null;
      _iapStatusMessage = _iapConfigured
          ? null
          : (exposeErrors ? 'Produkt nicht verfügbar.' : null);
    } catch (e) {
      _iapConfigured = false;
      _iapStatusMessage = exposeErrors ? 'IAP nicht verfügbar: $e' : null;
    }
  }

  Future<bool> buyPremium() async {
    final productId = currentLifetimeProductId;
    if (productId == null) {
      _iapStatusMessage = 'Käufe sind nicht konfiguriert.';
      notifyListeners();
      return false;
    }

    if (_purchaseBusy) return false;
    _purchaseBusy = true;
    _iapStatusMessage = null;
    notifyListeners();

    try {
      if (!_iapConfigured || _premiumProduct == null) {
        await _configureIapIfPossible(exposeErrors: true);
      }

      final product = _premiumProduct;
      if (product == null) {
        _iapStatusMessage = 'Produkt nicht verfügbar.';
        notifyListeners();
        return false;
      }

      final ok = await _iapClient.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!ok) {
        _iapStatusMessage = 'Kauf konnte nicht gestartet werden.';
        notifyListeners();
        return false;
      }
      // Actual premium activation happens in purchaseStream handler.
      return true;
    } catch (e) {
      _iapStatusMessage = 'Kauf fehlgeschlagen: $e';
      notifyListeners();
      return false;
    } finally {
      _purchaseBusy = false;
      notifyListeners();
    }
  }

  Future<bool> restorePurchases() async {
    if (currentLifetimeProductId == null) {
      _iapStatusMessage = 'Käufe sind nicht konfiguriert.';
      notifyListeners();
      return false;
    }
    if (_purchaseBusy) return false;

    _purchaseBusy = true;
    _iapStatusMessage = null;
    notifyListeners();
    try {
      if (!_iapConfigured) {
        await _configureIapIfPossible(exposeErrors: true);
      }
      if (!_iapConfigured) {
        _iapStatusMessage = 'Produkt nicht verfügbar.';
        notifyListeners();
        return false;
      }
      await _iapClient.restorePurchases();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final synced = await syncPremiumFromStore();
        if (!synced && !_isPremium) {
          return false;
        }
      }
      // Restores will flow through purchaseStream handler.
      return true;
    } catch (e) {
      _iapStatusMessage = 'Wiederherstellen fehlgeschlagen: $e';
      notifyListeners();
      return false;
    } finally {
      _purchaseBusy = false;
      notifyListeners();
    }
  }

  Future<bool> syncPremiumFromStore() async {
    final productId = currentLifetimeProductId;
    if (productId == null) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;

    final verified = await _verifyWithFreshIosReceipt(productId: productId);
    if (verified) {
      await setPremium(true);
      _iapStatusMessage = null;
      notifyListeners();
      return true;
    }

    if (!_isPremium) {
      _iapStatusMessage = 'Premium konnte nicht synchronisiert werden.';
    } else {
      _iapStatusMessage = 'Premium-Verifizierung fehlgeschlagen.';
    }
    notifyListeners();
    return false;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final expectedProductId = currentLifetimeProductId;
    if (expectedProductId == null) return;

    for (final purchase in purchases) {
      if (purchase.productID != expectedProductId) continue;

      if (purchase.status == PurchaseStatus.pending) {
        _iapStatusMessage = 'Zahlung ausstehend …';
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _iapStatusMessage =
            'Kauf fehlgeschlagen: ${purchase.error?.message ?? 'Unbekannter Fehler'}';
        notifyListeners();
        if (purchase.pendingCompletePurchase) {
          await _iapClient.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final platform =
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
        final verified = await _verifyAndSyncWithFallback(
          platform: platform,
          productId: expectedProductId,
          primaryVerificationData:
              purchase.verificationData.serverVerificationData,
        );

        if (verified) {
          await setPremium(true);
          _iapStatusMessage = null;
          notifyListeners();
        } else {
          _iapStatusMessage =
              'Kauf erkannt, aber Verifizierung fehlgeschlagen. Bitte "Käufe wiederherstellen" erneut ausführen.';
          notifyListeners();
        }

        if (purchase.pendingCompletePurchase) {
          await _iapClient.completePurchase(purchase);
        }
      }
    }
  }

  Future<bool> _verifyAndSyncWithFallback({
    required String platform,
    required String productId,
    required String primaryVerificationData,
  }) async {
    final verificationData = primaryVerificationData.trim();
    final primaryLooksLikeSk2Jws =
        platform == 'ios' && _looksLikeStoreKit2Jws(verificationData);

    if (primaryLooksLikeSk2Jws) {
      final ok = await _verifyWithFreshIosReceipt(productId: productId);
      if (ok) return true;
    }

    if (verificationData.isNotEmpty) {
      final ok = await _premiumSyncClient.verifyAndSync(
        platform: platform,
        productId: productId,
        verificationData: verificationData,
      );
      if (ok) return true;
    }

    if (platform == 'ios') {
      return _verifyWithFreshIosReceipt(productId: productId);
    }

    return false;
  }

  Future<bool> _verifyWithFreshIosReceipt({required String productId}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final refreshed = await _iosReceiptClient.refreshServerVerificationData();
      final receipt = refreshed?.trim();
      if (receipt == null || receipt.isEmpty) {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          continue;
        }
        return false;
      }
      final ok = await _premiumSyncClient.verifyAndSync(
        platform: 'ios',
        productId: productId,
        verificationData: receipt,
      );
      if (ok) return true;
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
    return false;
  }

  bool _looksLikeStoreKit2Jws(String verificationData) {
    if (verificationData.isEmpty) return false;
    final parts = verificationData.split('.');
    if (parts.length != 3) return false;
    final b64Url = RegExp(r'^[A-Za-z0-9\-_]+$');
    return parts.every((part) => part.isNotEmpty && b64Url.hasMatch(part));
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
