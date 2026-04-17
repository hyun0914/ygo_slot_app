import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class CloudSyncService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> uploadAll() async {
    final uid = AuthService.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final data = <String, dynamic>{};

    for (final key in keys) {
      final v = prefs.get(key);
      if (v != null) data[key] = v;
    }

    await _db
        .collection('users')
        .doc(uid)
        .collection('game_data')
        .doc('prefs')
        .set({'data': data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> downloadAndMerge() async {
    final uid = AuthService.uid;
    if (uid == null) return;

    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('game_data')
        .doc('prefs')
        .get();

    if (!doc.exists) return;

    final raw = doc.data()?['data'];
    if (raw == null || raw is! Map) return;

    final prefs = await SharedPreferences.getInstance();
    for (final entry in (raw as Map<String, dynamic>).entries) {
      final k = entry.key;
      final v = entry.value;
      if (v is String) {
        await prefs.setString(k, v);
      } else if (v is int) {
        await prefs.setInt(k, v);
      } else if (v is double) {
        await prefs.setDouble(k, v);
      } else if (v is bool) {
        await prefs.setBool(k, v);
      } else if (v is List) {
        await prefs.setStringList(k, v.cast<String>());
      }
    }
  }

  static Future<void> uploadAfterDraw() => uploadAll();
}
