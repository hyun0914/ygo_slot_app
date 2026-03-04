import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/draw_history_entry.dart';

class DrawHistoryStore {
  static const _kKey = 'ygo_draw_history_v1';
  static const _kMaxEntries = 30;

  static Future<List<DrawHistoryEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => DrawHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DrawHistory] 파싱 실패: $e');
      return [];
    }
  }

  static Future<void> addEntry(DrawHistoryEntry entry) async {
    final all = await loadAll();
    all.insert(0, entry);
    final trimmed = all.take(_kMaxEntries).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
