import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/daily_slot_rule.dart';

class TodayRulePrefs {
  static const _kPrefix = 'random_draw_today_rule_v1';

  static String _key(int count) => '${_kPrefix}_$count';

  static Future<DailySlotRule?> load({required int count, required String todayKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(count));
    if (raw == null || raw.isEmpty) return null;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final dateKey = (m['dateKey'] as String?) ?? '';
      if (dateKey != todayKey) {
        await prefs.remove(_key(count));
        return null;
      }

      final kindStr = (m['kind'] as String?) ?? 'normal';
      final kind = switch (kindStr) {
        'boss' => DayKind.boss,
        _ => DayKind.normal,
      };

      final list = (m['targets'] as List?) ?? const [];
      final targets = list.map((e) {
        if (e is! Map<String, dynamic>) return SlotTarget.category('');
        final cardId = (e['cardId'] as num?)?.toInt();
        if (cardId != null && cardId > 0) {
          return SlotTarget.exact(
            cardId,
            cardName: e['cardName'] as String?,
            imageUrl: e['imageUrl'] as String?,
          );
        }
        return SlotTarget.category((e['category'] as String?) ?? '');
      }).toList();

      if (targets.length != 3) return null;
      return DailySlotRule(dateKey: dateKey, kind: kind, targets: targets);
    } catch (e) {
      debugPrint('[TodayRule] 파싱 실패, 저장된 데이터 삭제: $e');
      await prefs.remove(_key(count));
      return null;
    }
  }

  static Future<void> save(DailySlotRule rule, {required int count}) async {
    final prefs = await SharedPreferences.getInstance();
    final m = <String, dynamic>{
      'dateKey': rule.dateKey,
      'kind': switch (rule.kind) {
        DayKind.normal => 'normal',
        DayKind.boss => 'boss',
      },
      'targets': rule.targets.map((t) {
        if (t.cardId != null) {
          return {'cardId': t.cardId, 'cardName': t.cardName, 'imageUrl': t.imageUrl};
        }
        return {'category': t.category};
      }).toList(),
    };
    await prefs.setString(_key(count), jsonEncode(m));
  }
}
