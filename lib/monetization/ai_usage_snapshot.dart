class AiUsageSnapshot {
  final String dateKey;
  final int used;
  final int limit;
  final bool? isPremium;

  const AiUsageSnapshot({
    required this.dateKey,
    required this.used,
    required this.limit,
    this.isPremium,
  });

  int get remaining => (limit - used).clamp(0, limit);
}
