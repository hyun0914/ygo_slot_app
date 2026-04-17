import 'package:shared_preferences/shared_preferences.dart';

import '../domain/level_config.dart';

class LevelStore {
  static const _kKey = 'ygo_level_v1';

  static Future<int> getTotalXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kKey) ?? 0;
  }

  /// Add XP. Returns (newXp, newLevel, oldLevel) — caller can detect level-up.
  static Future<({int xp, int level, int oldLevel})> addXp(int gain) async {
    final prefs = await SharedPreferences.getInstance();
    final oldXp = prefs.getInt(_kKey) ?? 0;
    final oldLevel = xpToLevel(oldXp);
    final newXp = oldXp + gain;
    await prefs.setInt(_kKey, newXp);
    final newLevel = xpToLevel(newXp);
    return (xp: newXp, level: newLevel, oldLevel: oldLevel);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
