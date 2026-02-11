import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stirnraten/monetization/ai_usage_snapshot.dart';
import 'package:stirnraten/monetization/monetization_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
      'applyServerAiUsage upgrades local premium flag when server says premium',
      () async {
    final iap = _FakeIapClient();
    final verifier = _FakePremiumSyncClient();
    final receipts = _FakeIosReceiptClient();
    final controller = MonetizationController(
      iapClient: iap,
      premiumSyncClient: verifier,
      iosReceiptClient: receipts,
    );

    await controller.init();
    expect(controller.isPremium, isFalse);

    await controller.applyServerAiUsage(
      const AiUsageSnapshot(
        dateKey: '2026-02-11',
        used: 1,
        limit: 3,
        isPremium: true,
      ),
    );
    expect(controller.isPremium, isTrue);

    final reloaded = MonetizationController(
      iapClient: _FakeIapClient(),
      premiumSyncClient: _FakePremiumSyncClient(),
      iosReceiptClient: _FakeIosReceiptClient(),
    );
    await reloaded.init();
    expect(reloaded.isPremium, isTrue);
    expect(reloaded.dailyAiGenerationsDateKey, '2026-02-11');
    expect(reloaded.dailyAiGenerationsUsed, 1);
  });

  test(
      'applyServerAiUsage downgrades stale local premium when server says free',
      () async {
    final controller = MonetizationController(
      iapClient: _FakeIapClient(),
      premiumSyncClient: _FakePremiumSyncClient(),
      iosReceiptClient: _FakeIosReceiptClient(),
    );
    await controller.init();
    await controller.setPremium(true);
    expect(controller.isPremium, isTrue);

    await controller.applyServerAiUsage(
      const AiUsageSnapshot(
        dateKey: '2026-02-11',
        used: 3,
        limit: 3,
        isPremium: false,
      ),
    );

    expect(controller.isPremium, isFalse);
  });

  test(
      'purchased update unlocks premium, verifies backend and completes purchase',
      () async {
    final iap = _FakeIapClient();
    final verifier = _FakePremiumSyncClient(result: true);
    final receipts = _FakeIosReceiptClient();
    final controller = MonetizationController(
      iapClient: iap,
      premiumSyncClient: verifier,
      iosReceiptClient: receipts,
    );
    await controller.init();

    final purchase = PurchaseDetails(
      productID: 'com.stirnraten.app.premium_lifetime',
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'server_receipt_blob',
        source: 'app_store',
      ),
      transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
      status: PurchaseStatus.purchased,
    )..pendingCompletePurchase = true;

    iap.emit(<PurchaseDetails>[purchase]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.isPremium, isTrue);
    expect(verifier.calls, 1);
    expect(verifier.lastPlatform, 'ios');
    expect(verifier.lastProductId, 'com.stirnraten.app.premium_lifetime');
    expect(verifier.lastVerificationData, 'server_receipt_blob');
    expect(iap.completedPurchases, 1);
    expect(controller.iapStatusMessage, isNull);
  });

  test('restored update without valid verification does not unlock premium',
      () async {
    final iap = _FakeIapClient();
    final verifier = _FakePremiumSyncClient(result: false);
    final receipts = _FakeIosReceiptClient();
    final controller = MonetizationController(
      iapClient: iap,
      premiumSyncClient: verifier,
      iosReceiptClient: receipts,
    );
    await controller.init();

    final restored = PurchaseDetails(
      productID: 'com.stirnraten.app.premium_lifetime',
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'server_receipt_blob',
        source: 'app_store',
      ),
      transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
      status: PurchaseStatus.restored,
    );

    iap.emit(<PurchaseDetails>[restored]);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(controller.isPremium, isFalse);
    expect(verifier.calls, 1);
    expect(
      controller.iapStatusMessage,
      contains('Kauf erkannt, aber Verifizierung fehlgeschlagen'),
    );
  });

  test(
      'iOS fallback receipt verification unlocks premium when first verify fails',
      () async {
    final iap = _FakeIapClient();
    final verifier = _FakePremiumSyncClient(sequence: <bool>[false, true]);
    final receipts = _FakeIosReceiptClient(
      refreshedReceipt: 'refreshed_receipt_blob',
    );
    final controller = MonetizationController(
      iapClient: iap,
      premiumSyncClient: verifier,
      iosReceiptClient: receipts,
    );
    await controller.init();

    final purchase = PurchaseDetails(
      productID: 'com.stirnraten.app.premium_lifetime',
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'sk2_jws_or_old_receipt',
        source: 'app_store',
      ),
      transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
      status: PurchaseStatus.purchased,
    );

    iap.emit(<PurchaseDetails>[purchase]);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.isPremium, isTrue);
    expect(verifier.calls, 2);
    expect(verifier.verificationHistory.first, 'sk2_jws_or_old_receipt');
    expect(verifier.verificationHistory.last, 'refreshed_receipt_blob');
    expect(receipts.refreshCalls, 1);
    expect(controller.iapStatusMessage, isNull);
  });

  test('iOS StoreKit2 JWS payload uses refreshed receipt for verification',
      () async {
    final iap = _FakeIapClient();
    final verifier = _FakePremiumSyncClient(result: true);
    final receipts = _FakeIosReceiptClient(
      refreshedReceipt: 'refreshed_receipt_blob',
    );
    final controller = MonetizationController(
      iapClient: iap,
      premiumSyncClient: verifier,
      iosReceiptClient: receipts,
    );
    await controller.init();

    final purchase = PurchaseDetails(
      productID: 'com.stirnraten.app.premium_lifetime',
      verificationData: PurchaseVerificationData(
        localVerificationData: '{"tx":"debug"}',
        serverVerificationData:
            'eyJhbGciOiJIUzI1NiJ9.eyJwcm9kdWN0SWQiOiJ4In0.sig',
        source: 'app_store',
      ),
      transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
      status: PurchaseStatus.purchased,
    );

    iap.emit(<PurchaseDetails>[purchase]);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.isPremium, isTrue);
    expect(verifier.calls, 1);
    expect(verifier.verificationHistory.single, 'refreshed_receipt_blob');
    expect(receipts.refreshCalls, 1);
  });

  test('syncPremiumFromStore verifies using refreshed iOS receipt', () async {
    final iap = _FakeIapClient();
    final verifier = _FakePremiumSyncClient(result: true);
    final receipts = _FakeIosReceiptClient(
      refreshedReceipt: 'refresh_only_receipt',
    );
    final controller = MonetizationController(
      iapClient: iap,
      premiumSyncClient: verifier,
      iosReceiptClient: receipts,
    );
    await controller.init();

    final ok = await controller.syncPremiumFromStore();
    expect(ok, isTrue);
    expect(controller.isPremium, isTrue);
    expect(verifier.calls, 1);
    expect(verifier.verificationHistory.single, 'refresh_only_receipt');
    expect(receipts.refreshCalls, 1);
    expect(
      controller.iapStatusMessage,
      isNull,
    );
  });

  test('restorePurchases on iOS performs receipt sync and unlocks premium',
      () async {
    final iap = _FakeIapClient();
    final verifier = _FakePremiumSyncClient(result: true);
    final receipts = _FakeIosReceiptClient(
      refreshedReceipt: 'restore_receipt_blob',
    );
    final controller = MonetizationController(
      iapClient: iap,
      premiumSyncClient: verifier,
      iosReceiptClient: receipts,
    );
    await controller.init();

    final ok = await controller.restorePurchases();
    expect(ok, isTrue);
    expect(iap.restoreCalls, 1);
    expect(receipts.refreshCalls, 1);
    expect(controller.isPremium, isTrue);
    expect(controller.iapStatusMessage, isNull);
  });
}

class _FakeIapClient implements MonetizationIapClient {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  int completedPurchases = 0;
  int restoreCalls = 0;
  bool available = true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: <ProductDetails>[
        ProductDetails(
          id: 'com.stirnraten.app.premium_lifetime',
          title: 'Premium',
          description: 'Lifetime',
          price: '4,99 €',
          rawPrice: 4.99,
          currencyCode: 'EUR',
        ),
      ],
      notFoundIDs: const <String>[],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls += 1;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases += 1;
  }

  void emit(List<PurchaseDetails> purchases) {
    _controller.add(purchases);
  }
}

class _FakePremiumSyncClient implements PremiumSyncClient {
  final bool result;
  final List<bool>? sequence;
  int calls = 0;
  String? lastPlatform;
  String? lastProductId;
  String? lastVerificationData;
  final List<String> verificationHistory = <String>[];

  _FakePremiumSyncClient({this.result = true, this.sequence});

  @override
  Future<bool> verifyAndSync({
    required String platform,
    required String productId,
    required String verificationData,
  }) async {
    calls += 1;
    lastPlatform = platform;
    lastProductId = productId;
    lastVerificationData = verificationData;
    verificationHistory.add(verificationData);
    if (sequence != null && calls <= sequence!.length) {
      return sequence![calls - 1];
    }
    return result;
  }
}

class _FakeIosReceiptClient implements IosReceiptClient {
  final String? refreshedReceipt;
  int refreshCalls = 0;

  _FakeIosReceiptClient({this.refreshedReceipt});

  @override
  Future<String?> refreshServerVerificationData() async {
    refreshCalls += 1;
    return refreshedReceipt;
  }
}
