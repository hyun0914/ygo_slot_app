import 'package:shared_preferences/shared_preferences.dart';

class DrawStatsStore {
  static const _kKey = 'ygo_draw_stats_v1';

  static Future<int> getTotalDraws() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kKey) ?? 0;
  }

  static Future<int> increment([int by = 1]) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kKey) ?? 0;
    final updated = current + by;
    await prefs.setInt(_kKey, updated);
    return updated;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
