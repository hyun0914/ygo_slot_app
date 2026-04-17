import 'dart:math';

import '../../../../core/models/ygopro_card.dart';

class WeeklyChallengeDef {
  final String id;
  final String title;
  final String description;
  final int requiredCount;
  final String condKey; // e.g. "attr:dark", "race:dragon", "type:spell", "atk_min:2000", "level_max:4"

  const WeeklyChallengeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredCount,
    required this.condKey,
  });

  bool matchCard(YgoCard card) {
    final parts = condKey.split(':');
    if (parts.length < 2) return false;
    final kind = parts[0];
    final value = parts.sublist(1).join(':');

    switch (kind) {
      case 'attr':
        return card.attribute?.toLowerCase() == value;
      case 'race':
        return card.race?.toLowerCase() == value;
      case 'type':
        if (value == 'spell') return card.type.toLowerCase().contains('spell');
        if (value == 'trap') return card.type.toLowerCase().contains('trap');
        if (value == 'monster') return !card.type.toLowerCase().contains('spell') && !card.type.toLowerCase().contains('trap');
        return false;
      case 'atk_min':
        final n = int.tryParse(value) ?? 0;
        return (card.atk ?? 0) >= n;
      case 'atk_max':
        final n = int.tryParse(value) ?? 9999;
        return (card.atk ?? 9999) <= n;
      case 'level_max':
        final n = int.tryParse(value) ?? 12;
        final lv = card.level;
        return lv != null && lv <= n;
      case 'level_min':
        final n = int.tryParse(value) ?? 1;
        final lv = card.level;
        return lv != null && lv >= n;
      default:
        return false;
    }
  }

  int countMatches(List<YgoCard> cards) => cards.where(matchCard).length;

  bool isCompleted(List<YgoCard> cards) => countMatches(cards) >= requiredCount;
}

const kWeeklyChallenges = <WeeklyChallengeDef>[
  WeeklyChallengeDef(id: 'dark_2',        title: 'DARK의 힘',    description: 'DARK 속성 카드를 2장 이상 뽑아라',    requiredCount: 2, condKey: 'attr:dark'),
  WeeklyChallengeDef(id: 'dragon_1',      title: '드래곤 소환',  description: '드래곤족 카드를 1장 이상 뽑아라',    requiredCount: 1, condKey: 'race:dragon'),
  WeeklyChallengeDef(id: 'spell_2',       title: '마법의 힘',    description: '마법 카드를 2장 이상 뽑아라',        requiredCount: 2, condKey: 'type:spell'),
  WeeklyChallengeDef(id: 'atk2000_2',     title: '강자의 증명',  description: 'ATK 2000 이상 카드를 2장 이상 뽑아라',requiredCount: 2, condKey: 'atk_min:2000'),
  WeeklyChallengeDef(id: 'lv4_3',         title: '속공의 달인',  description: '레벨 4 이하 카드를 3장 이상 뽑아라',  requiredCount: 3, condKey: 'level_max:4'),
  WeeklyChallengeDef(id: 'light_2',       title: '빛의 전사',    description: 'LIGHT 속성 카드를 2장 이상 뽑아라',  requiredCount: 2, condKey: 'attr:light'),
  WeeklyChallengeDef(id: 'warrior_1',     title: '전사의 기개',  description: '전사족 카드를 1장 이상 뽑아라',      requiredCount: 1, condKey: 'race:warrior'),
  WeeklyChallengeDef(id: 'trap_1',        title: '함정의 달인',  description: '함정 카드를 1장 이상 뽑아라',        requiredCount: 1, condKey: 'type:trap'),
  WeeklyChallengeDef(id: 'fire_2',        title: '불꽃 결투자',  description: 'FIRE 속성 카드를 2장 이상 뽑아라',   requiredCount: 2, condKey: 'attr:fire'),
  WeeklyChallengeDef(id: 'lv7plus_1',     title: '최강 몬스터',  description: '레벨 7 이상 카드를 1장 이상 뽑아라', requiredCount: 1, condKey: 'level_min:7'),
  WeeklyChallengeDef(id: 'spellcaster_1', title: '마법사 소환',  description: '마법사족 카드를 1장 이상 뽑아라',    requiredCount: 1, condKey: 'race:spellcaster'),
  WeeklyChallengeDef(id: 'water_2',       title: '해저의 지배자',description: 'WATER 속성 카드를 2장 이상 뽑아라', requiredCount: 2, condKey: 'attr:water'),
  WeeklyChallengeDef(id: 'earth_2',       title: '대지의 수호자',description: 'EARTH 속성 카드를 2장 이상 뽑아라', requiredCount: 2, condKey: 'attr:earth'),
  WeeklyChallengeDef(id: 'monster_3',     title: '몬스터 수집',  description: '몬스터 카드를 3장 이상 뽑아라',      requiredCount: 3, condKey: 'type:monster'),
  WeeklyChallengeDef(id: 'atk0_1',        title: '영점 공격력',  description: 'ATK 0 카드를 1장 이상 뽑아라',       requiredCount: 1, condKey: 'atk_max:0'),
];

WeeklyChallengeDef pickWeeklyChallenge({required DateTime now}) {
  final weekNum = _isoWeekNumber(now);
  final seed = now.year * 100 + weekNum;
  final r = Random(seed);
  return kWeeklyChallenges[r.nextInt(kWeeklyChallenges.length)];
}

int _isoWeekNumber(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final jan4 = DateTime(d.year, 1, 4);
  final startOfWeek1 = jan4.subtract(Duration(days: (jan4.weekday - 1) % 7));
  if (d.isBefore(startOfWeek1)) {
    return _isoWeekNumber(DateTime(d.year - 1, 12, 31));
  }
  return ((d.difference(startOfWeek1).inDays) ~/ 7) + 1;
}
