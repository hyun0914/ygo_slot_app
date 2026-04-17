import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/collection_entry.dart';

class CollectionStore {
  static const _kKey = 'ygo_collection_v1';

  static Future<Map<int, CollectionEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List;
      return Map.fromEntries(
        list.map((e) {
          final entry = CollectionEntry.fromJson(e as Map<String, dynamic>);
          return MapEntry(entry.id, entry);
        }),
      );
    } catch (e) {
      debugPrint('[Collection] 파싱 실패: $e');
      return {};
    }
  }

  /// Add a batch of cards. Returns updated collection size (unique cards).
  static Future<int> addCards(
      List<({int id, String name, String imageUrl})> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final collection = await loadAll();

    final today = _todayKey();
    bool changed = false;

    for (final c in cards) {
      final existing = collection[c.id];
      if (existing != null) {
        collection[c.id] = existing.withCount(existing.count + 1);
      } else {
        collection[c.id] = CollectionEntry(
          id: c.id,
          name: c.name,
          imageUrl: c.imageUrl,
          firstSeen: today,
          count: 1,
        );
      }
      changed = true;
    }

    if (changed) {
      await prefs.setString(
        _kKey,
        jsonEncode(collection.values.map((e) => e.toJson()).toList()),
      );
    }

    return collection.length;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
