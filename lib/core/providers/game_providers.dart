import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/collection/application/collection_store.dart';
import '../../features/collection/domain/collection_entry.dart';
import '../../features/favorites/application/favorites_store.dart';
import '../../features/level/application/level_store.dart';
import '../../features/level/domain/level_config.dart';
import '../../features/random_draw/application/draw_stats_store.dart';
import '../../features/random_draw/application/jackpot_streak_store.dart';
import '../../features/random_draw/application/target_pity_store.dart';
import '../../features/random_draw/domain/target_pity.dart';

// ── XP ──────────────────────────────────────────────────────────────────────

class XpNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() => LevelStore.getTotalXp();

  Future<({int xp, int level, int oldLevel})> addXp(int gain) async {
    final result = await LevelStore.addXp(gain);
    state = AsyncData(result.xp);
    return result;
  }

  void setValue(int xp) => state = AsyncData(xp);
}

final xpProvider = AsyncNotifierProvider<XpNotifier, int>(XpNotifier.new);

// ── Total draws ──────────────────────────────────────────────────────────────

class TotalDrawsNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() => DrawStatsStore.getTotalDraws();

  Future<int> increment() async {
    final newDraws = await DrawStatsStore.increment();
    state = AsyncData(newDraws);
    return newDraws;
  }

  void setValue(int value) => state = AsyncData(value);
}

final totalDrawsProvider =
    AsyncNotifierProvider<TotalDrawsNotifier, int>(TotalDrawsNotifier.new);

// ── Collection ───────────────────────────────────────────────────────────────

class CollectionNotifier extends AsyncNotifier<Map<int, CollectionEntry>> {
  @override
  Future<Map<int, CollectionEntry>> build() => CollectionStore.loadAll();

  Future<int> addCards(
      List<({int id, String name, String imageUrl})> cards) async {
    final newSize = await CollectionStore.addCards(cards);
    state = AsyncData(await CollectionStore.loadAll());
    return newSize;
  }

  Future<void> reload() async {
    state = AsyncData(await CollectionStore.loadAll());
  }
}

final collectionProvider =
    AsyncNotifierProvider<CollectionNotifier, Map<int, CollectionEntry>>(
        CollectionNotifier.new);

final collectionSizeProvider = Provider<int>(
  (ref) => ref.watch(collectionProvider).valueOrNull?.length ?? 0,
);

// ── Favorites ────────────────────────────────────────────────────────────────

class FavoriteIdsNotifier extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() => FavoritesStore.loadIds();

  Future<bool> toggle(int cardId) async {
    final isNow = await FavoritesStore.toggle(cardId);
    final updated = Set<int>.from(state.valueOrNull ?? {});
    if (isNow) {
      updated.add(cardId);
    } else {
      updated.remove(cardId);
    }
    state = AsyncData(updated);
    return isNow;
  }

  Future<void> reload() async {
    state = AsyncData(await FavoritesStore.loadIds());
  }
}

final favoriteIdsProvider =
    AsyncNotifierProvider<FavoriteIdsNotifier, Set<int>>(
        FavoriteIdsNotifier.new);

// ── Jackpot streak ───────────────────────────────────────────────────────────

class StreakNotifier extends AsyncNotifier<JackpotStreakData> {
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<JackpotStreakData> build() {
    final now = DateTime.now();
    return JackpotStreakStore.load(
      todayKey: _dateKey(now),
      yesterdayKey: _dateKey(now.subtract(const Duration(days: 1))),
    );
  }

  Future<JackpotStreakData> updateStreak() async {
    final now = DateTime.now();
    final current = state.valueOrNull ?? JackpotStreakData.empty;
    final updated = await JackpotStreakStore.update(
      todayKey: _dateKey(now),
      yesterdayKey: _dateKey(now.subtract(const Duration(days: 1))),
      current: current,
    );
    state = AsyncData(updated);
    return updated;
  }
}

final streakProvider =
    AsyncNotifierProvider<StreakNotifier, JackpotStreakData>(StreakNotifier.new);

// ── Target pity (천장 시스템) ─────────────────────────────────────────────────

class TargetPityNotifier extends AsyncNotifier<TargetPityState> {
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<TargetPityState> build() async {
    final loaded = await TargetPityStore.load();
    return TargetPityStore.ensureToday(
      current: loaded,
      todayKey: _dateKey(DateTime.now()),
    );
  }

  /// 오늘의 타겟 날짜와 어긋나 있으면(=타겟이 바뀌었으면) missCount를 리셋한다.
  Future<TargetPityState> ensureToday() async {
    final current = state.valueOrNull ?? TargetPityState.empty;
    final updated = await TargetPityStore.ensureToday(
      current: current,
      todayKey: _dateKey(DateTime.now()),
    );
    state = AsyncData(updated);
    return updated;
  }

  /// 뽑기 결과를 반영하고 갱신된 상태를 반환한다.
  Future<TargetPityState> recordDraw({required bool jackpot}) async {
    final current = state.valueOrNull ?? TargetPityState.empty;
    final updated = await TargetPityStore.recordDraw(current: current, jackpot: jackpot);
    state = AsyncData(updated);
    return updated;
  }

  /// 연속 뽑기 베팅 결과를 missCount에 직접 반영한다.
  Future<TargetPityState> applyBatchBetResult({
    required int newMissCount,
    required bool jackpotOccurred,
  }) async {
    final current = state.valueOrNull ?? TargetPityState.empty;
    final updated = await TargetPityStore.applyBatchBetResult(
      current: current,
      newMissCount: newMissCount,
      jackpotOccurred: jackpotOccurred,
    );
    state = AsyncData(updated);
    return updated;
  }
}

final targetPityProvider =
    AsyncNotifierProvider<TargetPityNotifier, TargetPityState>(TargetPityNotifier.new);

// ── Derived: level ───────────────────────────────────────────────────────────

final levelProvider = Provider<int>(
  (ref) => xpToLevel(ref.watch(xpProvider).valueOrNull ?? 0),
);
