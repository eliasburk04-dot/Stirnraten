class AiUsageSnapshot {
  final String dateKey;
  final int used;
  final int limit;

  const AiUsageSnapshot({
    required this.dateKey,
    required this.used,
    required this.limit,
  });

  int get remaining => (limit - used).clamp(0, limit);
}

