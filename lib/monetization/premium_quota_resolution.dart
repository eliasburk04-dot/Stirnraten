enum PremiumQuotaResolution {
  none,
  showFreeUpsell,
  attemptPremiumRecovery,
}

PremiumQuotaResolution resolvePremiumQuotaResolution({
  required bool quotaExceeded,
  required bool isPremium,
}) {
  if (!quotaExceeded) return PremiumQuotaResolution.none;
  if (isPremium) return PremiumQuotaResolution.attemptPremiumRecovery;
  return PremiumQuotaResolution.showFreeUpsell;
}
