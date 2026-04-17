import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeeklyChallengeStore {
  static const _kKey = 'ygo_weekly_challenge_v1';

  static String _weekKey(DateTime now) {
    final weekNum = _isoWeekNumber(now);
    return '${now.year}_w$weekNum';
  }

  static Future<int> getCompletionsThisWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return 0;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final key = _weekKey(DateTime.now());
      if (m['week'] != key) return 0;
      return (m['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[WeeklyChallenge] 파싱 실패: $e');
      return 0;
    }
  }

  static Future<int> recordCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _weekKey(DateTime.now());
    int count = 0;

    final raw = prefs.getString(_kKey);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        if (m['week'] == key) {
          count = (m['count'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}
    }

    count++;
    await prefs.setString(_kKey, jsonEncode({'week': key, 'count': count}));
    return count;
  }

  static int _isoWeekNumber(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final jan4 = DateTime(d.year, 1, 4);
    final startOfWeek1 = jan4.subtract(Duration(days: (jan4.weekday - 1) % 7));
    if (d.isBefore(startOfWeek1)) {
      return _isoWeekNumber(DateTime(d.year - 1, 12, 31));
    }
    return ((d.difference(startOfWeek1).inDays) ~/ 7) + 1;
  }
}
