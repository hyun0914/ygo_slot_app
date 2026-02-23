import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/models/ygopro_card.dart';

// -----------------------------
// Slot rule (domain)
// -----------------------------
enum DayKind { normal, spotlight, boss }

class DailySlotRule {
  final String dateKey;
  final DayKind kind;
  final List<SlotTarget> targets; // 3개

  DailySlotRule({
    required this.dateKey,
    required this.kind,
    required this.targets,
  });
}

class SlotTarget {
  final int? cardId;
  final String? category;

  final String? cardName;
  final String? imageUrl;

  const SlotTarget._({
    this.cardId,
    this.category,
    this.cardName,
    this.imageUrl,
  });

  factory SlotTarget.exact(int cardId, {String? cardName, String? imageUrl}) {
    return SlotTarget._(cardId: cardId, cardName: cardName, imageUrl: imageUrl);
  }

  factory SlotTarget.category(String category) {
    return SlotTarget._(category: category);
  }
}

// -----------------------------
// Build rule from pool
// -----------------------------
class _CatCandidate {
  final String key; // ex) "lv:4"
  final double ratio; // pool 내 등장 비율
  const _CatCandidate(this.key, this.ratio);
}

List<_CatCandidate> _buildCategoryCandidatesWithRatio(List<YgoCard> pool) {
  if (pool.isEmpty) return const [];

  final total = pool.length.toDouble();
  final Map<String, int> counts = {};

  void addKey(String k) {
    if (k.trim().isEmpty) return;
    counts[k] = (counts[k] ?? 0) + 1;
  }

  for (final c in pool) {
    final lv = c.level;
    if (lv != null) addKey('lv:$lv');

    final attr = c.attribute?.toLowerCase().trim();
    if (attr != null && attr.isNotEmpty) addKey('attr:$attr');

    final race = c.race?.toLowerCase().trim();
    if (race != null && race.isNotEmpty) addKey('race:$race');

    final t = c.type.toLowerCase();
    if (t.contains('quick-play')) addKey('sub:quick-play');
    if (t.contains('continuous')) addKey('sub:continuous');
    if (t.contains('counter')) addKey('sub:counter');

    if (t.contains('fusion')) addKey('extra:fusion');
    if (t.contains('synchro')) addKey('extra:synchro');
    if (t.contains('xyz')) addKey('extra:xyz');
    if (t.contains('link')) addKey('extra:link');

    final atk = c.atk;
    if (atk != null) {
      if (atk <= 1500) {
        addKey('atk:0-1500');
      } else if (atk <= 2500) {
        addKey('atk:1501-2500');
      }
      else {
        addKey('atk:2501+');
      }
    }
  }

  final list = counts.entries
      .map((e) => _CatCandidate(e.key, e.value / total))
      .where((c) => c.ratio >= 0.01) // 노이즈 제거
      .toList();

  list.sort((a, b) => b.ratio.compareTo(a.ratio));
  return list;
}

List<_CatCandidate> _pickCatsWithKindDiversity(
    List<_CatCandidate> candidates,
    Random r,
    int n,
    ) {
  if (candidates.isEmpty) return const [];

  final list = [...candidates]..shuffle(r);
  final picked = <_CatCandidate>[];
  final usedKinds = <String>{};

  // 1차: kind 중복 없이
  for (final c in list) {
    final kind = c.key.split(':').first;
    if (usedKinds.contains(kind)) continue;
    picked.add(c);
    usedKinds.add(kind);
    if (picked.length == n) return picked;
  }

  // 2차: 부족하면 중복 허용
  for (final c in list) {
    if (picked.any((p) => p.key == c.key)) continue;
    picked.add(c);
    if (picked.length == n) break;
  }

  while (picked.length < n) {
    picked.add(list[r.nextInt(list.length)]);
  }

  return picked;
}

List<YgoCard> _exactCandidates(List<YgoCard> pool) {
  return pool.where((c) {
    final url = (c.imageUrl).trim();
    return c.id > 0 && url.isNotEmpty;
  }).toList();
}

List<YgoCard> _pickUniqueCards(List<YgoCard> list, Random r, int n) {
  if (list.isEmpty) return const [];
  final shuffled = [...list]..shuffle(r);

  final picked = <YgoCard>[];
  final used = <int>{};

  for (final c in shuffled) {
    if (used.add(c.id)) picked.add(c);
    if (picked.length == n) break;
  }

  while (picked.length < n) {
    picked.add(shuffled[r.nextInt(shuffled.length)]);
  }
  return picked;
}

DayKind pickTodayKind({
  required int count, // 3/5/7
  required Random r,
}) {
  // 도전(3): 보스20 / 스포30 / 일반50
  // 기본(5): 보스10 / 스포20 / 일반70
  // 편안(7): 보스12 / 스포24 / 일반64
  final (boss, spot, normal) = switch (count) {
    3 => (20, 30, 50),
    5 => (10, 20, 70),
    7 => (12, 24, 64),
    _ => (10, 20, 70),
  };

  final roll = r.nextInt(100);
  if (roll < boss) return DayKind.boss;
  if (roll < boss + spot) return DayKind.spotlight;
  return DayKind.normal;
}

DailySlotRule buildTodayRule(
    List<YgoCard> pool, {
      required DateTime now,
      required int count,
    }) {
  final d = DateUtils.dateOnly(now);
  final key =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 날짜 + 모드까지 포함해서 “모드별로도 하루 고정”
  final seed = (d.year * 10000 + d.month * 100 + d.day) * 10 + (count % 10);
  final r = Random(seed);

  final kind = pickTodayKind(count: count, r: r);

  final catCandidates = _buildCategoryCandidatesWithRatio(pool);
  final exactPool = _exactCandidates(pool);

  List<SlotTarget> targets = [];

  if (kind == DayKind.normal) {
    final cats = _pickCatsWithKindDiversity(catCandidates, r, 3);
    targets = cats.map((c) => SlotTarget.category(c.key)).toList();
  } else if (kind == DayKind.spotlight) {
    final picked1 = _pickUniqueCards(exactPool, r, 1);
    final exactPicked = picked1.isEmpty ? null : picked1.first;
    final cats = _pickCatsWithKindDiversity(catCandidates, r, 2);

    if (exactPicked == null) {
      final fallback = _pickCatsWithKindDiversity(catCandidates, r, 3);
      targets = fallback.map((c) => SlotTarget.category(c.key)).toList();
      return DailySlotRule(dateKey: key, kind: DayKind.normal, targets: targets);
    }

    targets.add(SlotTarget.exact(
      exactPicked.id,
      cardName: exactPicked.name,
      imageUrl: exactPicked.imageUrl,
    ));
    targets.addAll(cats.map((c) => SlotTarget.category(c.key)));
  } else {
    // boss
    final picked = _pickUniqueCards(exactPool, r, 3);
    if (picked.isEmpty) {
      final fallback = _pickCatsWithKindDiversity(catCandidates, r, 3);
      targets = fallback.map((c) => SlotTarget.category(c.key)).toList();
      return DailySlotRule(dateKey: key, kind: DayKind.normal, targets: targets);
    }
    targets = picked.take(3).map((c) {
      return SlotTarget.exact(c.id, cardName: c.name, imageUrl: c.imageUrl);
    }).toList();
  }

  // 안전장치: 3개 보장
  while (targets.length < 3 && catCandidates.isNotEmpty) {
    targets.add(
      SlotTarget.category(catCandidates[r.nextInt(catCandidates.length)].key),
    );
  }

  return DailySlotRule(dateKey: key, kind: kind, targets: targets.take(3).toList());
}

// -----------------------------
// Matching / hits (domain)
// -----------------------------
bool _matchCategory(YgoCard c, String key) {
  final parts = key.split(':');
  if (parts.length < 2) return false;
  final kind = parts[0];
  final val = parts.sublist(1).join(':');

  switch (kind) {
    case 'lv':
      return c.level?.toString() == val;

    case 'attr':
      return (c.attribute ?? '').toLowerCase() == val;

    case 'race':
      return (c.race ?? '').toLowerCase() == val;

    case 'sub':
      final t = c.type.toLowerCase();
      if (val == 'quick-play') return t.contains('quick-play');
      if (val == 'continuous') return t.contains('continuous');
      if (val == 'counter') return t.contains('counter');
      return false;

    case 'extra':
      final t = c.type.toLowerCase();
      return t.contains(val);

    case 'atk':
      final atk = c.atk;
      if (atk == null) return false;
      if (val == '0-1500') return atk <= 1500;
      if (val == '1501-2500') return atk >= 1501 && atk <= 2500;
      if (val == '2501+') return atk >= 2501;
      return false;
  }
  return false;
}

bool matchesTarget({
  required YgoCard card,
  required SlotTarget t,
}) {
  // exact
  if (t.cardId != null) return card.id == t.cardId;

  final key = (t.category ?? '').trim();
  if (key.isEmpty) return false;

  // 레거시
  if (!key.contains(':')) {
    if (key.startsWith('Lv')) return card.level?.toString() == key.substring(2);
    if (key == 'Quick-Play') return card.type.contains('Quick-Play');
    if (key == 'Counter') return card.type.contains('Counter');
    if (key == 'Continuous') return card.type.contains('Continuous');
    if (key == 'Spell') return card.type.contains('Spell');
    if (key == 'Trap') return card.type.contains('Trap');
    return false;
  }

  return _matchCategory(card, key);
}

bool anyMatchTarget({
  required List<YgoCard> cards,
  required SlotTarget t,
}) {
  return cards.any((c) => matchesTarget(card: c, t: t));
}

int countSlotHits({
  required List<YgoCard> cards,
  required DailySlotRule? rule,
}) {
  if (rule == null) return 0;

  var hits = 0;
  for (final t in rule.targets) {
    if (anyMatchTarget(cards: cards, t: t)) hits++;
  }
  return hits;
}
