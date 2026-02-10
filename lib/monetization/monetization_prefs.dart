import 'package:shared_preferences/shared_preferences.dart';

class MonetizationPrefsSnapshot {
  final bool isPremium;
  final int dailyAiUsed;
  final String dailyAiDateKey;

  const MonetizationPrefsSnapshot({
    required this.isPremium,
    required this.dailyAiUsed,
    required this.dailyAiDateKey,
  });
}

class MonetizationPrefs {
  static const String _kIsPremium = 'monetization.isPremium';
  static const String _kDailyUsed = 'monetization.dailyAiGenerationsUsed';
  static const String _kDailyKey = 'monetization.dailyAiGenerationsDateKey';

  Future<MonetizationPrefsSnapshot> load({
    required String defaultDateKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return MonetizationPrefsSnapshot(
      isPremium: prefs.getBool(_kIsPremium) ?? false,
      dailyAiUsed: prefs.getInt(_kDailyUsed) ?? 0,
      dailyAiDateKey: prefs.getString(_kDailyKey) ?? defaultDateKey,
    );
  }

  Future<void> savePremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, value);
  }

  Future<void> saveDailyAiUsage({
    required int used,
    required String dateKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDailyUsed, used);
    await prefs.setString(_kDailyKey, dateKey);
  }
}

