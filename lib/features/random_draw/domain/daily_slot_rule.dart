import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/models/ygopro_card.dart';

// -----------------------------
// Slot rule (domain)
// -----------------------------
enum DayKind { normal, boss }

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
  // 도전(3): 보스20 / 일반80
  // 기본(5): 보스10 / 일반90
  // 편안(7): 보스12 / 일반88
  final boss = switch (count) {
    3 => 20,
    5 => 10,
    7 => 12,
    _ => 10,
  };

  final roll = r.nextInt(100);
  if (roll < boss) return DayKind.boss;
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

  // kind는 연출(보스 카운트다운, 색상/아이콘 등) 용도로만 사용되고,
  // 타겟 구성 자체는 항상 "특정 카드 3장"으로 동일하다.
  final kind = pickTodayKind(count: count, r: r);

  final exactPool = _exactCandidates(pool);
  final picked = _pickUniqueCards(exactPool, r, 3);

  final targets = picked.take(3).map((c) {
    return SlotTarget.exact(c.id, cardName: c.name, imageUrl: c.imageUrl);
  }).toList();

  if (targets.isEmpty) {
    debugPrint('[DailyRule] 경고: 이미지 있는 카드가 풀에 없어 타겟을 만들지 못함');
  }

  return DailySlotRule(dateKey: key, kind: kind, targets: targets);
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
