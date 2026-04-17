import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BattleStatsStore {
  static const _kKey = 'ygo_battle_stats_v1';

  static Future<({int wins, int losses, int draws})> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return (wins: 0, losses: 0, draws: 0);
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (
        wins: (m['w'] as num?)?.toInt() ?? 0,
        losses: (m['l'] as num?)?.toInt() ?? 0,
        draws: (m['d'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('[Battle] 파싱 실패: $e');
      return (wins: 0, losses: 0, draws: 0);
    }
  }

  static Future<void> record({required String result}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final m = {
      'w': current.wins + (result == 'win' ? 1 : 0),
      'l': current.losses + (result == 'loss' ? 1 : 0),
      'd': current.draws + (result == 'draw' ? 1 : 0),
    };
    await prefs.setString(_kKey, jsonEncode(m));
  }
}
