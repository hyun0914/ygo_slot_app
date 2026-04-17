import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/achievement.dart';

class AchievementEvent {
  final bool drew;
  final bool hitOccurred;
  final bool jackpot;
  final bool bossJackpot;
  final int mode;
  final bool isBatch;
  final int currentStreak;
  final int totalJackpots;
  final int totalDraws;
  final int collectionSize;

  const AchievementEvent({
    this.drew = false,
    this.hitOccurred = false,
    this.jackpot = false,
    this.bossJackpot = false,
    this.mode = 5,
    this.isBatch = false,
    this.currentStreak = 0,
    this.totalJackpots = 0,
    this.totalDraws = 0,
    this.collectionSize = 0,
  });
}

class AchievementStore {
  static const _kKey = 'ygo_achievements_v1';

  static Future<Map<String, DateTime>> _loadUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, DateTime.parse(v as String)));
    } catch (e) {
      debugPrint('[Achievement] 파싱 실패: $e');
      return {};
    }
  }

  static Future<List<Achievement>> loadAll() async {
    final unlocked = await _loadUnlocked();
    return kAllAchievements.map((a) {
      if (unlocked.containsKey(a.id)) {
        return a.copyWith(unlocked: true, unlockedAt: unlocked[a.id]);
      }
      return a;
    }).toList();
  }

  /// Check event against all un-unlocked achievements.
  /// Returns list of newly unlocked ones.
  static Future<List<Achievement>> checkAndUnlock(AchievementEvent e) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    Map<String, DateTime> unlocked = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        unlocked = m.map((k, v) => MapEntry(k, DateTime.parse(v as String)));
      } catch (_) {}
    }

    final newlyUnlocked = <Achievement>[];

    void tryUnlock(String id) {
      if (unlocked.containsKey(id)) return;
      final def = kAllAchievements.where((a) => a.id == id).firstOrNull;
      if (def == null) return;
      final now = DateTime.now();
      unlocked[id] = now;
      newlyUnlocked.add(def.copyWith(unlocked: true, unlockedAt: now));
    }

    if (e.drew) tryUnlock('first_draw');
    if (e.hitOccurred) tryUnlock('first_hit');
    if (e.jackpot) {
      tryUnlock('first_jackpot');
      if (e.mode == 3) tryUnlock('challenge_jackpot');
      if (e.mode == 7) tryUnlock('comfort_jackpot');
    }
    if (e.bossJackpot) tryUnlock('boss_jackpot');
    if (e.isBatch) tryUnlock('batch_first');
    if (e.currentStreak >= 3) tryUnlock('streak_3');
    if (e.currentStreak >= 7) tryUnlock('streak_7');
    if (e.currentStreak >= 30) tryUnlock('streak_30');
    if (e.totalDraws >= 10) tryUnlock('draws_10');
    if (e.totalDraws >= 100) tryUnlock('draws_100');
    if (e.totalDraws >= 1000) tryUnlock('draws_1000');
    if (e.totalJackpots >= 5) tryUnlock('jackpots_5');
    if (e.totalJackpots >= 10) tryUnlock('jackpots_10');
    if (e.totalJackpots >= 50) tryUnlock('jackpots_50');
    if (e.collectionSize >= 10) tryUnlock('collection_10');
    if (e.collectionSize >= 50) tryUnlock('collection_50');
    if (e.collectionSize >= 100) tryUnlock('collection_100');

    if (newlyUnlocked.isNotEmpty) {
      await prefs.setString(
        _kKey,
        jsonEncode(unlocked.map((k, v) => MapEntry(k, v.toIso8601String()))),
      );
    }

    return newlyUnlocked;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
