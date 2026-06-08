import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/target_pity.dart';

class TargetPityStore {
  static const kKey = 'ygo_target_pity_v1';

  static Future<TargetPityState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kKey);
    if (raw == null || raw.isEmpty) return TargetPityState.empty;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return TargetPityState(
        dateKey: (m['dateKey'] as String?) ?? '',
        missCount: (m['missCount'] as num?)?.toInt() ?? 0,
        clearedCount: (m['clearedCount'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('[TargetPity] 파싱 실패: $e');
      return TargetPityState.empty;
    }
  }

  static Future<void> _save(TargetPityState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kKey, jsonEncode({
      'dateKey': s.dateKey,
      'missCount': s.missCount,
      'clearedCount': s.clearedCount,
    }));
  }

  /// 오늘의 타겟 기준으로 상태를 보정한다.
  /// 날짜(=타겟)가 바뀌었으면 missCount를 0으로 리셋한다 (누적 달성 횟수는 유지).
  static Future<TargetPityState> ensureToday({
    required TargetPityState current,
    required String todayKey,
  }) async {
    if (current.dateKey == todayKey) return current;

    final next = TargetPityState(
      dateKey: todayKey,
      missCount: 0,
      clearedCount: current.clearedCount,
    );
    await _save(next);
    return next;
  }

  /// 뽑기 결과를 반영한다.
  /// 잭팟이면 missCount를 리셋하고 누적 달성 횟수를 +1, 아니면 missCount를 +1 한다.
  static Future<TargetPityState> recordDraw({
    required TargetPityState current,
    required bool jackpot,
  }) async {
    final next = jackpot
        ? current.copyWith(missCount: 0, clearedCount: current.clearedCount + 1)
        : current.copyWith(missCount: current.missCount + 1);

    await _save(next);
    return next;
  }

  /// 연속 뽑기 베팅 결과를 missCount에 직접 반영한다.
  /// 일반 증감 로직을 거치지 않고 정산된 최종 포인트로 덮어쓴다.
  static Future<TargetPityState> applyBatchBetResult({
    required TargetPityState current,
    required int newMissCount,
    required bool jackpotOccurred,
  }) async {
    final next = current.copyWith(
      missCount: newMissCount,
      clearedCount: jackpotOccurred ? current.clearedCount + 1 : current.clearedCount,
    );

    await _save(next);
    return next;
  }
}
