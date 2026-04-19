import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JackpotStreakData {
  final int streak;
  final int best;
  final int total;
  final bool todayDone;

  const JackpotStreakData({
    required this.streak,
    required this.best,
    required this.total,
    required this.todayDone,
  });

  static const empty = JackpotStreakData(streak: 0, best: 0, total: 0, todayDone: false);
}

class JackpotStreakStore {
  static const kKey = 'ygo_jackpot_streak_v1';

  static Future<JackpotStreakData> load({
    required String todayKey,
    required String yesterdayKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kKey);
    if (raw == null || raw.isEmpty) return JackpotStreakData.empty;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final lastDate = (m['lastDate'] as String?) ?? '';
      final streak = (m['streak'] as num?)?.toInt() ?? 0;
      final best = (m['best'] as num?)?.toInt() ?? 0;
      final total = (m['total'] as num?)?.toInt() ?? 0;

      if (lastDate == todayKey) {
        return JackpotStreakData(streak: streak, best: best, total: total, todayDone: true);
      } else if (lastDate == yesterdayKey) {
        return JackpotStreakData(streak: streak, best: best, total: total, todayDone: false);
      } else {
        return JackpotStreakData(streak: 0, best: best, total: total, todayDone: false);
      }
    } catch (e) {
      debugPrint('[Streak] 파싱 실패: $e');
      return JackpotStreakData.empty;
    }
  }

  static Future<JackpotStreakData> update({
    required String todayKey,
    required String yesterdayKey,
    required JackpotStreakData current,
  }) async {
    if (current.todayDone) return current;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kKey);

    String lastDate = '';
    int streak = 0;
    int best = current.best;
    int total = current.total;

    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        lastDate = (m['lastDate'] as String?) ?? '';
        streak = (m['streak'] as num?)?.toInt() ?? 0;
        best = (m['best'] as num?)?.toInt() ?? current.best;
        total = (m['total'] as num?)?.toInt() ?? current.total;
      } catch (_) {}
    }

    if (lastDate == todayKey) {
      return JackpotStreakData(streak: streak, best: best, total: total, todayDone: true);
    } else if (lastDate == yesterdayKey) {
      streak++;
    } else {
      streak = 1;
    }

    total++;
    if (streak > best) best = streak;

    await prefs.setString(kKey, jsonEncode({
      'lastDate': todayKey,
      'streak': streak,
      'best': best,
      'total': total,
    }));

    return JackpotStreakData(streak: streak, best: best, total: total, todayDone: true);
  }
}
