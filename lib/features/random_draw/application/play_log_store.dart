import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records daily play + jackpot dates for the streak calendar.
class PlayLogStore {
  static const _kKey = 'ygo_play_log_v1';
  static const _kMaxDays = 90;

  static Future<({List<String> playDates, List<String> jackpotDates})>
      load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      return (playDates: <String>[], jackpotDates: <String>[]);
    }
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final play = ((m['p'] as List?) ?? []).map((e) => e as String).toList();
      final jackpot =
          ((m['j'] as List?) ?? []).map((e) => e as String).toList();
      return (playDates: play, jackpotDates: jackpot);
    } catch (e) {
      debugPrint('[PlayLog] 파싱 실패: $e');
      return (playDates: <String>[], jackpotDates: <String>[]);
    }
  }

  static Future<void> recordPlay({required bool jackpot}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = await load();

    final today = _todayKey();
    final cutoff =
        DateTime.now().subtract(const Duration(days: _kMaxDays));
    final cutoffStr = _dateKey(cutoff);

    // Deduplicate and trim old entries
    final playSet = {...data.playDates, today}
        .where((d) => d.compareTo(cutoffStr) >= 0)
        .toList()
      ..sort();

    final jackpotSet = jackpot
        ? ({...data.jackpotDates, today}
            .where((d) => d.compareTo(cutoffStr) >= 0)
            .toList()
          ..sort())
        : data.jackpotDates
            .where((d) => d.compareTo(cutoffStr) >= 0)
            .toList();

    await prefs.setString(
      _kKey,
      jsonEncode({'p': playSet, 'j': jackpotSet}),
    );
  }

  static String _todayKey() => _dateKey(DateTime.now());

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
