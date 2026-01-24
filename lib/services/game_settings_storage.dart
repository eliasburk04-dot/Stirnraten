import 'package:shared_preferences/shared_preferences.dart';

import '../engine/stirnraten_engine.dart';

class GameSettingsStorage {
  static const String _timeKey = 'stirnraten_selected_time_v1';
  static const String _modeKey = 'stirnraten_selected_mode_v1';

  Future<int?> getSelectedTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_timeKey);
  }

  Future<GameMode?> getSelectedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_modeKey);
    if (value == null) return null;
    for (final mode in GameMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  Future<void> saveSelectedTime(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timeKey, seconds);
  }

  Future<void> saveSelectedMode(GameMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }
}
