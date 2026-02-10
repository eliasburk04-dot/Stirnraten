class DailyQuota {
  static ({String dateKey, int used}) normalize({
    required String storedDateKey,
    required int storedUsed,
    required String todayKey,
  }) {
    if (storedDateKey != todayKey) {
      return (dateKey: todayKey, used: 0);
    }
    return (dateKey: storedDateKey, used: storedUsed);
  }
}

