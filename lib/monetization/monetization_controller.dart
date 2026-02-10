import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_auth_service.dart';
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
  static const String _envRcIosKey =
      String.fromEnvironment('REVENUECAT_API_KEY_IOS');
  static const String _envRcAndroidKey =
      String.fromEnvironment('REVENUECAT_API_KEY_ANDROID');

  final MonetizationPrefs _prefs;

  bool _initialized = false;
  bool _iapConfigured = false;

  bool _isPremium = false;
  int _dailyAiGenerationsUsed = 0;
  String _dailyAiGenerationsDateKey = '';

  bool _purchaseBusy = false;
  String? _iapStatusMessage;

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

  String? get _currentRevenueCatApiKey {
    final ios = _envRcIosKey.trim();
    final android = _envRcAndroidKey.trim();

    if (kIsWeb) {
      // The plugin provides a web implementation, but we don't sell Premium on web.
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

  Future<void> syncPremiumToSupabase() => _syncPremiumToSupabase();

  Future<void> _configureIapIfPossible() async {
    final apiKey = _currentRevenueCatApiKey;
    final productId = currentLifetimeProductId;
    if (apiKey == null || productId == null) {
      _iapConfigured = false;
      return;
    }

    try {
      final appUserId = await _resolveStableAppUserId();
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = appUserId,
      );

      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);

      _iapConfigured = true;
      _iapStatusMessage = null;

      if (_isPremium) {
        unawaited(_syncPremiumToSupabase());
      }
    } catch (e) {
      _iapConfigured = false;
      _iapStatusMessage = 'IAP nicht verfügbar: $e';
    }
  }

  Future<String?> _resolveStableAppUserId() async {
    // If Supabase is configured, use its (anonymous) user id. This lets the backend
    // reliably map Premium to the same user for server-side guardrails.
    try {
      final sb = Supabase.instance.client;
      final auth = SupabaseAuthService(sb);
      await auth.ensureAnonymousSession(timeout: const Duration(seconds: 12));
      final uid = sb.auth.currentUser?.id;
      if (uid != null && uid.trim().isNotEmpty) {
        return uid.trim();
      }
    } catch (_) {
      // Ignore: fallback to RevenueCat anonymous user.
    }
    return null;
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _applyCustomerInfo(info);
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final productId = currentLifetimeProductId;
    final hasEntitlement = info.entitlements.active.containsKey('premium');
    final hasProduct = productId != null &&
        info.allPurchasedProductIdentifiers.contains(productId);
    final nextPremium = hasEntitlement || hasProduct;
    if (nextPremium != _isPremium) {
      unawaited(setPremium(nextPremium));
      if (nextPremium) {
        unawaited(_syncPremiumToSupabase());
      }
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
      final products = await Purchases.getProducts(
        <String>[productId],
        productCategory: ProductCategory.nonSubscription,
      );
      if (products.isEmpty) {
        _iapStatusMessage = 'Produkt nicht verfügbar.';
        notifyListeners();
        return false;
      }

      final result = await Purchases.purchase(
        PurchaseParams.storeProduct(products.first),
      );
      _applyCustomerInfo(result.customerInfo);
      _iapStatusMessage = _isPremium ? null : 'Kauf abgeschlossen, aber Premium nicht aktiv.';
      notifyListeners();
      return _isPremium;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        _iapStatusMessage = null;
        notifyListeners();
        return false;
      }
      _iapStatusMessage = 'Kauf fehlgeschlagen: ${e.message ?? e.code}';
      notifyListeners();
      return false;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancelled') || msg.contains('canceled')) {
        _iapStatusMessage = null;
        notifyListeners();
        return false;
      }
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
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      if (_isPremium) {
        _iapStatusMessage = null;
      } else {
        _iapStatusMessage = 'Keine Käufe gefunden.';
      }
      notifyListeners();
      return _isPremium;
    } on PlatformException catch (e) {
      _iapStatusMessage = 'Wiederherstellen fehlgeschlagen: ${e.message ?? e.code}';
      notifyListeners();
      return false;
    } catch (e) {
      _iapStatusMessage = 'Wiederherstellen fehlgeschlagen: $e';
      notifyListeners();
      return false;
    } finally {
      _purchaseBusy = false;
      notifyListeners();
    }
  }

  Future<void> _syncPremiumToSupabase() async {
    if (!_isPremium) return;
    try {
      final sb = Supabase.instance.client;
      // Requires a Supabase session JWT; ensure we have one.
      final auth = SupabaseAuthService(sb);
      await auth.ensureAnonymousSession(timeout: const Duration(seconds: 12));
      await sb.functions.invoke('sync-premium');
    } catch (_) {
      // Offline / Supabase not configured: ignore. Server-side guards will still treat as Free.
    }
  }

  @override
  void dispose() {
    if (_iapConfigured) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    super.dispose();
  }
}
