import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../collection/domain/collection_entry.dart';

class FavoritesStore {
  static const _kKey = 'ygo_favorites_v1';

  static Future<Set<int>> loadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => (e as num).toInt()).toSet();
    } catch (e) {
      debugPrint('[Favorites] 파싱 실패: $e');
      return {};
    }
  }

  static Future<bool> toggle(int cardId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await loadIds();
    final isFav = ids.contains(cardId);
    if (isFav) {
      ids.remove(cardId);
    } else {
      ids.add(cardId);
    }
    await prefs.setString(_kKey, jsonEncode(ids.toList()));
    return !isFav; // returns new state
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}

class FavoriteCardEntry {
  final int id;
  final String name;
  final String imageUrl;
  final String addedDate;

  const FavoriteCardEntry({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.addedDate,
  });

  factory FavoriteCardEntry.fromCollection(CollectionEntry e) =>
      FavoriteCardEntry(
        id: e.id,
        name: e.name,
        imageUrl: e.imageUrl,
        addedDate: e.firstSeen,
      );
}
