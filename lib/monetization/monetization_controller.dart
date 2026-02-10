import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_usage_snapshot.dart';
import 'berlin_date.dart';
import 'daily_quota.dart';
import 'monetization_limits.dart';
import 'monetization_prefs.dart';

class MonetizationController extends ChangeNotifier {
  static const String _envIosProductId =
      String.fromEnvironment('IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID');
  static const String _envAndroidProductId =
      String.fromEnvironment('ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID');

  final MonetizationPrefs _prefs;
  final InAppPurchase _iap = InAppPurchase.instance;

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
  }) : _prefs = prefs ?? MonetizationPrefs();

  bool get isInitialized => _initialized;
  bool get isPremium => _isPremium;
  int get dailyAiGenerationsUsed => _dailyAiGenerationsUsed;
  String get dailyAiGenerationsDateKey => _dailyAiGenerationsDateKey;

  int get maxWordsPerList =>
      MonetizationLimits.maxWordsPerList(isPremium: _isPremium);

  bool get isPurchaseBusy => _purchaseBusy;
  bool get iapConfigured => _iapConfigured;
  String? get iapStatusMessage => _iapStatusMessage;

  String? get currentLifetimeProductId {
    final ios = _envIosProductId.trim();
    final android = _envAndroidProductId.trim();

    if (kIsWeb) {
      // No in-app purchases on web. Keep null to avoid purchase entry points.
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios.isEmpty ? null : ios;
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
    _dailyAiGenerationsUsed = snapshot.dailyAiUsed;
    _dailyAiGenerationsDateKey = snapshot.dailyAiDateKey;
    _resetDailyQuotaIfNeeded();

    await _configureIapIfPossible();

    _initialized = true;
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
    _dailyAiGenerationsDateKey = snapshot.dateKey;
    _dailyAiGenerationsUsed = snapshot.used;
    await _prefs.saveDailyAiUsage(
      used: _dailyAiGenerationsUsed,
      dateKey: _dailyAiGenerationsDateKey,
    );
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    if (_isPremium == value) return;
    _isPremium = value;
    await _prefs.savePremium(value);
    notifyListeners();
  }

  Future<void> _configureIapIfPossible() async {
    final productId = currentLifetimeProductId;
    if (productId == null) {
      _iapConfigured = false;
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android)) {
        _iapStatusMessage =
            'IAP Produkt-ID fehlt. Setze IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID / ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID.';
      }
      return;
    }

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        _iapConfigured = false;
        _iapStatusMessage = 'Store nicht verfügbar.';
        return;
      }

      _purchaseSub?.cancel();
      _purchaseSub = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (_) {},
      );

      final details = await _iap.queryProductDetails(<String>{productId});
      if (details.error != null) {
        _iapConfigured = false;
        _iapStatusMessage = 'Produktabfrage fehlgeschlagen.';
        return;
      }
      _premiumProduct =
          details.productDetails.isEmpty ? null : details.productDetails.first;

      _iapConfigured = _premiumProduct != null;
      _iapStatusMessage = _iapConfigured ? null : 'Produkt nicht verfügbar.';
    } catch (e) {
      _iapConfigured = false;
      _iapStatusMessage = 'IAP nicht verfügbar: $e';
    }
  }

  Future<bool> buyPremium() async {
    final productId = currentLifetimeProductId;
    if (!_iapConfigured || productId == null) {
      _iapStatusMessage = 'Käufe sind nicht konfiguriert.';
      notifyListeners();
      return false;
    }

    if (_purchaseBusy) return false;
    _purchaseBusy = true;
    _iapStatusMessage = null;
    notifyListeners();

    try {
      final product = _premiumProduct;
      if (product == null) {
        _iapStatusMessage = 'Produkt nicht verfügbar.';
        notifyListeners();
        return false;
      }

      final ok = await _iap.buyNonConsumable(
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
    if (!_iapConfigured) {
      _iapStatusMessage = 'Käufe sind nicht konfiguriert.';
      notifyListeners();
      return false;
    }
    if (_purchaseBusy) return false;

    _purchaseBusy = true;
    _iapStatusMessage = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
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
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Immediate local unlock for UX; backend verification happens next.
        await setPremium(true);

        final verified = await _verifyAndSyncToSupabase(
          platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          productId: expectedProductId,
          verificationData: purchase.verificationData.serverVerificationData,
        );

        if (!verified) {
          _iapStatusMessage =
              'Premium gekauft. Verifizierung läuft oder ist fehlgeschlagen.';
          notifyListeners();
        } else {
          _iapStatusMessage = null;
          notifyListeners();
        }

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<bool> _verifyAndSyncToSupabase({
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
      if (data is Map && data['premium'] == true) {
        await setPremium(true);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
