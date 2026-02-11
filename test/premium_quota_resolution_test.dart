import 'package:flutter_test/flutter_test.dart';
import 'package:stirnraten/monetization/premium_quota_resolution.dart';

void main() {
  test('returns none when there is no quota error', () {
    final result = resolvePremiumQuotaResolution(
      quotaExceeded: false,
      isPremium: false,
    );
    expect(result, PremiumQuotaResolution.none);
  });

  test('returns upsell for free users with quota exceeded', () {
    final result = resolvePremiumQuotaResolution(
      quotaExceeded: true,
      isPremium: false,
    );
    expect(result, PremiumQuotaResolution.showFreeUpsell);
  });

  test('returns premium recovery for premium users with quota exceeded', () {
    final result = resolvePremiumQuotaResolution(
      quotaExceeded: true,
      isPremium: true,
    );
    expect(result, PremiumQuotaResolution.attemptPremiumRecovery);
  });
}
