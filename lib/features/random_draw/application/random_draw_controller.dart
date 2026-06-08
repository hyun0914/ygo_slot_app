import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/api_client.dart';
import '../../../core/models/ygopro_card.dart';
import '../domain/draw_filter.dart';

class RandomDrawController {
  final YgoApiClient apiClient;
  final _random = Random();

  // 데일리 풀 캐시 (날짜가 바뀌면 자동 무효화)
  List<YgoCard> _dailyPool = [];
  String? _dailyPoolDateKey;
  Future<void>? _dailyPoolFuture;

  // ID로 조회한 카드 캐시 (위시 카드 주입 시 API 재호출 절약)
  final Map<int, YgoCard> _cardByIdCache = {};

  RandomDrawController(this.apiClient);

  List<YgoCard> get cachedDailyPool => List.unmodifiable(_dailyPool);

  Future<List<YgoCard>> generateDraw(DrawFilter filter) async {
    final data = await apiClient.fetchCards(filter.toApiParams());
    final cards = data.map((e) => YgoCard.fromJson(e as Map<String, dynamic>)).toList();

    cards.shuffle(_random);

    final count = filter.count.clamp(1, cards.length);
    return cards.take(count).toList();
  }

  /// 데일리 풀을 반환합니다. 같은 날짜 내에서는 캐시를 재사용합니다.
  Future<List<YgoCard>> ensureDailyPool() async {
    final key = _todayKey(DateTime.now());

    if (_dailyPoolDateKey == key && _dailyPool.isNotEmpty) return _dailyPool;

    if (_dailyPoolFuture != null) {
      await _dailyPoolFuture;
      return _dailyPool;
    }

    _dailyPoolFuture = _fetchDailyPool(key);

    try {
      await _dailyPoolFuture;
    } finally {
      _dailyPoolFuture = null;
    }

    return _dailyPool;
  }

  Future<void> _fetchDailyPool(String key) async {
    _dailyPoolDateKey = key;
    _dailyPool = [];

    const tries = [200, 120, 80, 50];

    for (final n in tries) {
      try {
        final pool = await generateDraw(
          DrawFilter(count: n, type: null, attribute: null, levelExpr: null, atkExpr: null),
        );
        if (pool.isNotEmpty) {
          _dailyPool = pool;
          return;
        }
      } catch (e) {
        debugPrint('[DailyPool] 풀 크기 $n 로드 실패: $e');
      }
    }

    debugPrint('[DailyPool] 모든 시도 실패 — 데일리 룰 없이 진행');
  }

  /// 카드 ID로 전체 정보를 조회한다 (위시 카드 주입용).
  /// 데일리 풀에 이미 있으면 그걸 쓰고, 없으면 API에 직접 id로 질의한다.
  Future<YgoCard?> fetchCardById(int id) async {
    final cached = _cardByIdCache[id];
    if (cached != null) return cached;

    for (final c in _dailyPool) {
      if (c.id == id) {
        _cardByIdCache[id] = c;
        return c;
      }
    }

    try {
      final data = await apiClient.fetchCards({'id': id.toString()});
      if (data.isEmpty) return null;
      final card = YgoCard.fromJson(data.first as Map<String, dynamic>);
      _cardByIdCache[id] = card;
      return card;
    } catch (e) {
      debugPrint('[TargetPity] 카드($id) 조회 실패: $e');
      return null;
    }
  }

  static String _todayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}