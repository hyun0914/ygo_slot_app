import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../domain/decoder_card.dart';
import '../domain/guess_result.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class DecoderState {
  final bool isLoading;
  final String? error;
  final List<DecoderCard> pool;

  // 현재 카드
  final int cardIndex;
  final DecoderCard? answerCard;
  final String? freeRevealKey;          // 카드마다 1개 무료 공개
  final List<String> manualRevealedKeys; // 토큰 소모로 추가 공개

  // 힌트 토큰 (글로벌, 카드 바뀌어도 유지)
  final int hintTokens;

  // 추측
  final List<GuessResult> allCardGuesses; // 이 카드의 전체 추측 이력
  final int todayGuessCount;             // 오늘 사용한 추측 수 (최대 3)
  final bool isWon;

  // 필터 / 검색
  final Map<String, String?> activeFilters; // hintKey → raw 값
  final String filterSearch;
  final DecoderCard? selectedCard;

  const DecoderState({
    this.isLoading = true,
    this.error,
    this.pool = const [],
    this.cardIndex = 0,
    this.answerCard,
    this.freeRevealKey,
    this.manualRevealedKeys = const [],
    this.hintTokens = 3,
    this.allCardGuesses = const [],
    this.todayGuessCount = 0,
    this.isWon = false,
    this.activeFilters = const {},
    this.filterSearch = '',
    this.selectedCard,
  });

  List<String> get allRevealedKeys {
    final seen = <String>{};
    return [
      ?freeRevealKey,
      ...manualRevealedKeys,
    ].where(seen.add).toList();
  }

  int get guessesLeftToday => 3 - todayGuessCount;
  bool get canGuessToday => guessesLeftToday > 0 && !isWon;
  bool get canUseHint =>
      hintTokens > 0 && allRevealedKeys.length < kHintKeys.length;

  List<DecoderCard> get filteredPool {
    var cards = pool;
    if (filterSearch.isNotEmpty) {
      final lower = filterSearch.toLowerCase();
      cards = cards.where((c) => c.name.toLowerCase().contains(lower)).toList();
    }
    for (final entry in activeFilters.entries) {
      final val = entry.value;
      if (val == null) continue;
      switch (entry.key) {
        case 'monsterType':
          cards = cards.where((c) => c.frameType == val).toList();
        case 'attribute':
          cards = cards.where((c) => c.attribute == val).toList();
        case 'levelRankLink':
          final parts = val.split('_');
          if (parts.length == 2) {
            final type = parts[0];
            final num = int.tryParse(parts[1]);
            if (num != null) {
              cards = cards.where((c) {
                if (c.levelRankLink != num) return false;
                return switch (type) {
                  'link' => c.isLink,
                  'rank' => c.isXyz,
                  _ => !c.isLink && !c.isXyz,
                };
              }).toList();
            }
          }
        case 'race':
          cards = cards.where((c) => c.race == val).toList();
        case 'atkMin':
          final min = int.tryParse(val);
          if (min != null) {
            cards = cards.where((c) => c.atk != null && c.atk! >= min).toList();
          }
        case 'atkMax':
          final max = int.tryParse(val);
          if (max != null) {
            cards = cards.where((c) => c.atk != null && c.atk! <= max).toList();
          }
        case 'defMin':
          final min = int.tryParse(val);
          if (min != null) {
            cards = cards
                .where((c) => !c.isLink && c.def != null && c.def! >= min)
                .toList();
          }
        case 'defMax':
          final max = int.tryParse(val);
          if (max != null) {
            cards = cards
                .where((c) => !c.isLink && c.def != null && c.def! <= max)
                .toList();
          }
      }
    }
    return cards;
  }

  DecoderState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<DecoderCard>? pool,
    int? cardIndex,
    DecoderCard? answerCard,
    String? freeRevealKey,
    List<String>? manualRevealedKeys,
    int? hintTokens,
    List<GuessResult>? allCardGuesses,
    int? todayGuessCount,
    bool? isWon,
    Map<String, String?>? activeFilters,
    String? filterSearch,
    DecoderCard? selectedCard,
    bool clearSelectedCard = false,
  }) {
    return DecoderState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pool: pool ?? this.pool,
      cardIndex: cardIndex ?? this.cardIndex,
      answerCard: answerCard ?? this.answerCard,
      freeRevealKey: freeRevealKey ?? this.freeRevealKey,
      manualRevealedKeys: manualRevealedKeys ?? this.manualRevealedKeys,
      hintTokens: hintTokens ?? this.hintTokens,
      allCardGuesses: allCardGuesses ?? this.allCardGuesses,
      todayGuessCount: todayGuessCount ?? this.todayGuessCount,
      isWon: isWon ?? this.isWon,
      activeFilters: activeFilters ?? this.activeFilters,
      filterSearch: filterSearch ?? this.filterSearch,
      selectedCard:
          clearSelectedCard ? null : (selectedCard ?? this.selectedCard),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DecoderNotifier extends Notifier<DecoderState> {
  static const _poolKey = 'decoder_pool_v5';
  static const _poolTsKey = 'decoder_pool_ts_v5';
  static const _gameKey = 'decoder_game_v5';
  static const _poolTtlMs = 7 * 24 * 3600 * 1000;
  static const _maxTokens = 5;

  @override
  DecoderState build() {
    _load();
    return const DecoderState();
  }

  static String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // 두 날짜 문자열(YYYY-MM-DD) 사이의 경과일 계산
  static int _daysBetween(String from, String to) {
    try {
      final a = DateTime.parse(from);
      final b = DateTime.parse(to);
      return b.difference(a).inDays;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _load() async {
    try {
      final pool = await _loadPool();
      if (pool.isEmpty) {
        state = state.copyWith(
            isLoading: false, error: '카드 풀을 불러올 수 없어요. 네트워크를 확인해주세요.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_gameKey);
      final saved = raw != null && raw.isNotEmpty
          ? jsonDecode(raw) as Map<String, dynamic>
          : null;

      final today = _todayKey;

      // ── 힌트 토큰 ──
      int hintTokens;
      String lastTokenDate;
      if (saved == null) {
        hintTokens = 3;
        lastTokenDate = today;
      } else {
        lastTokenDate = saved['lastTokenDate'] as String? ?? today;
        final elapsed = _daysBetween(lastTokenDate, today);
        hintTokens = ((saved['hintTokens'] as num?)?.toInt() ?? 3) + elapsed;
        hintTokens = hintTokens.clamp(0, _maxTokens);
        if (elapsed > 0) lastTokenDate = today;
      }

      // ── 카드 정보 복원 ──
      final cardIndex = (saved?['cardIndex'] as num?)?.toInt() ??
          Random().nextInt(pool.length);
      final answerCard = pool[cardIndex % pool.length];
      final freeRevealKey = saved?['freeRevealKey'] as String? ??
          answerCard.revealOrder().first;
      final manualRevealedKeys =
          List<String>.from(saved?['manualRevealedKeys'] ?? []);
      final isWon = saved?['isWon'] as bool? ?? false;

      // ── 오늘 추측 복원 (날짜 바뀌면 초기화) ──
      int todayGuessCount = 0;
      List<GuessResult> allCardGuesses = [];

      if (saved != null) {
        final rawGuesses = (saved['allCardGuesses'] as List?) ?? [];
        allCardGuesses = rawGuesses.map((g) {
          final cardId = (g['cardId'] as num).toInt();
          final card = pool.firstWhere(
            (c) => c.id == cardId,
            orElse: () => answerCard,
          );
          final jRaw = (g['judgments'] as Map?) ?? {};
          final judgments = jRaw.map((k, v) => MapEntry(
              k.toString(), HintJudgment.values[(v as num).toInt()]));
          return GuessResult(card: card, judgments: judgments);
        }).toList();

        if (saved['todayDateKey'] == today) {
          todayGuessCount =
              (saved['todayGuessCount'] as num?)?.toInt() ?? 0;
        }
      }

      // 토큰이 변경됐으면 저장
      if (saved == null ||
          (saved['lastTokenDate'] as String?) != lastTokenDate ||
          (saved['hintTokens'] as num?)?.toInt() != hintTokens) {
        await _saveState(
          prefs: prefs,
          cardIndex: cardIndex,
          freeRevealKey: freeRevealKey,
          manualRevealedKeys: manualRevealedKeys,
          hintTokens: hintTokens,
          lastTokenDate: lastTokenDate,
          allCardGuesses: allCardGuesses,
          todayGuessCount: todayGuessCount,
          todayDateKey: today,
          isWon: isWon,
        );
      }

      state = state.copyWith(
        isLoading: false,
        pool: pool,
        cardIndex: cardIndex,
        answerCard: answerCard,
        freeRevealKey: freeRevealKey,
        manualRevealedKeys: manualRevealedKeys,
        hintTokens: hintTokens,
        allCardGuesses: allCardGuesses,
        todayGuessCount: todayGuessCount,
        isWon: isWon,
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('[Decoder] 로드 실패: $e\n$st');
      state = state.copyWith(
          isLoading: false, error: '게임을 불러오는 중 오류가 발생했어요.');
    }
  }

  Future<List<DecoderCard>> _loadPool() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_poolTsKey) ?? 0;
    final raw = prefs.getString(_poolKey) ?? '';

    if (raw.isNotEmpty &&
        DateTime.now().millisecondsSinceEpoch - ts < _poolTtlMs) {
      try {
        final list = jsonDecode(raw) as List;
        final cards = list
            .map((e) => DecoderCard.fromCacheJson(e as Map<String, dynamic>))
            .toList();
        if (cards.isNotEmpty) return cards;
      } catch (e) {
        debugPrint('[Decoder] 캐시 파싱 실패: $e');
      }
    }

    // num 제한 없이 전체 카드 가져오기 (필터링 후 몬스터만 캐시)
    final data = await YgoApiClient().fetchCards(
      {},
      timeout: const Duration(seconds: 45),
    );

    final cards = data
        .map((e) => DecoderCard.fromJson(e as Map<String, dynamic>))
        .where((c) =>
            frameTypeToKr.containsKey(c.frameType) &&
            attributeToKr.containsKey(c.attribute) &&
            raceToKr.containsKey(c.race))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (cards.isNotEmpty) {
      await prefs.setString(
          _poolKey, jsonEncode(cards.map((c) => c.toJson()).toList()));
      await prefs.setInt(_poolTsKey, DateTime.now().millisecondsSinceEpoch);
    }

    return cards;
  }

  Future<void> _saveState({
    SharedPreferences? prefs,
    required int cardIndex,
    required String freeRevealKey,
    required List<String> manualRevealedKeys,
    required int hintTokens,
    required String lastTokenDate,
    required List<GuessResult> allCardGuesses,
    required int todayGuessCount,
    required String todayDateKey,
    required bool isWon,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _gameKey,
      jsonEncode({
        'cardIndex': cardIndex,
        'freeRevealKey': freeRevealKey,
        'manualRevealedKeys': manualRevealedKeys,
        'hintTokens': hintTokens,
        'lastTokenDate': lastTokenDate,
        'todayDateKey': todayDateKey,
        'todayGuessCount': todayGuessCount,
        'isWon': isWon,
        'allCardGuesses': allCardGuesses
            .map((g) => {
                  'cardId': g.card.id,
                  'judgments':
                      g.judgments.map((k, v) => MapEntry(k, v.index)),
                })
            .toList(),
      }),
    );
  }

  Future<void> _persist() async {
    final s = state;
    if (s.answerCard == null || s.freeRevealKey == null) return;
    await _saveState(
      cardIndex: s.cardIndex,
      freeRevealKey: s.freeRevealKey!,
      manualRevealedKeys: s.manualRevealedKeys,
      hintTokens: s.hintTokens,
      lastTokenDate: _todayKey,
      allCardGuesses: s.allCardGuesses,
      todayGuessCount: s.todayGuessCount,
      todayDateKey: _todayKey,
      isWon: s.isWon,
    );
  }

  /// 힌트 토큰 1개 소모 → 속성 1개 추가 공개
  void useHint() {
    final s = state;
    if (!s.canUseHint || s.answerCard == null) return;

    final order = s.answerCard!.revealOrder();
    final revealed = s.allRevealedKeys.toSet();
    final nextKey = order.firstWhere((k) => !revealed.contains(k));

    state = state.copyWith(
      hintTokens: s.hintTokens - 1,
      manualRevealedKeys: [...s.manualRevealedKeys, nextKey],
    );
    _persist();
  }

  /// 카드 추측 제출
  Future<void> submitGuess() async {
    final s = state;
    final selected = s.selectedCard;
    final answer = s.answerCard;
    if (selected == null || answer == null || !s.canGuessToday) return;

    final result = GuessResult.compare(selected, answer);
    final isWon = selected.id == answer.id;

    // 맞은 속성은 힌트 소모 없이 공개 목록에 추가
    final alreadyRevealed = s.allRevealedKeys.toSet();
    final newReveals = kHintKeys
        .where((k) =>
            result.judgment(k) == HintJudgment.correct &&
            !alreadyRevealed.contains(k))
        .toList();

    state = state.copyWith(
      allCardGuesses: [...s.allCardGuesses, result],
      todayGuessCount: s.todayGuessCount + 1,
      isWon: isWon,
      manualRevealedKeys: [...s.manualRevealedKeys, ...newReveals],
      clearSelectedCard: true,
    );
    await _persist();
  }

  /// 정답 후 즉시 다음 카드로 이동 (랜덤)
  Future<void> advanceCard() async {
    final s = state;
    if (s.pool.isEmpty) return;

    int newIndex;
    do {
      newIndex = Random().nextInt(s.pool.length);
    } while (newIndex == s.cardIndex && s.pool.length > 1);
    final newCard = s.pool[newIndex];
    final newFreeKey = newCard.revealOrder().first;

    state = state.copyWith(
      cardIndex: newIndex,
      answerCard: newCard,
      freeRevealKey: newFreeKey,
      manualRevealedKeys: [],
      allCardGuesses: [],
      todayGuessCount: 0,
      isWon: false,
      clearSelectedCard: true,
      activeFilters: const {},
      filterSearch: '',
    );
    await _persist();
  }

  void setFilter(String key, String? rawValue) {
    final updated = Map<String, String?>.from(state.activeFilters);
    if (rawValue == null) {
      updated.remove(key);
    } else {
      updated[key] = rawValue;
    }
    state = state.copyWith(activeFilters: updated);
  }

  void setSearch(String query) {
    state = state.copyWith(filterSearch: query);
  }

  void selectCard(DecoderCard card) {
    state = state.copyWith(selectedCard: card);
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedCard: true);
  }

  Future<void> retry() async {
    state = const DecoderState();
    await _load();
  }
}

final decoderProvider =
    NotifierProvider<DecoderNotifier, DecoderState>(DecoderNotifier.new);
