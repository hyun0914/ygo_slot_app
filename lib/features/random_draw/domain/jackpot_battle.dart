import 'dart:math';

import '../../../core/models/ygopro_card.dart';

// -----------------------------
// 잭팟 배틀 미니게임 — domain
//
// 오늘의 타겟 3장을 모두 뽑아 잭팟을 달성하면, 그 3장이 자동으로 순서대로
// 상대 카드와 배틀한다 (수동 선택 없음). 라운드마다 ATK/DEF 중 하나를
// 무작위로 골라 비교하고, 동점이면 다른 스탯으로 한 번 더 비교하며,
// 그래도 진짜 무승부라면 3판 2승(서로 다른 무작위 몬스터로 진행)으로 승부를 가른다.
//
// 타겟이 마법/함정 카드라면 뽑힌 카드 중 몬스터로 대신 출전시키고,
// 대신 출전시킬 몬스터가 어디에도 없는 극단적인 경우(전부 마법/함정)에는
// "스펠 스피드" 등급을 비교해서 승패를 가른다.
// -----------------------------

enum BattleMode { atk, def }

enum SpellSpeedTier { speed1, speed2, speed3 }

bool isMonsterCard(YgoCard c) => c.type.toLowerCase().contains('monster');

bool _hasBattleStats(YgoCard c) => c.atk != null && c.def != null;

/// 실제 유희왕 룰을 기준으로 한 스펠 스피드 등급.
/// - Speed 1: 일반/지속/의식/장착/필드 마법, 몬스터의 기동/유발/기동 효과 (가장 느림)
/// - Speed 2: 일반 함정, 속공 마법, 몬스터의 유발즉시 효과
/// - Speed 3: 카운터 함정 (가장 빠름)
SpellSpeedTier spellSpeedTierOf(YgoCard card) {
  final type = card.type.toLowerCase();
  final race = (card.race ?? '').toLowerCase();

  if (type.contains('trap')) {
    return race.contains('counter') ? SpellSpeedTier.speed3 : SpellSpeedTier.speed2;
  }
  if (type.contains('spell')) {
    return race.contains('quick-play') ? SpellSpeedTier.speed2 : SpellSpeedTier.speed1;
  }
  // 몬스터 카드의 효과 속도는 텍스트만으로 구분하기 어려우므로 기본값(스피드 1)으로 취급한다.
  return SpellSpeedTier.speed1;
}

/// `excludeIds`에 없는 몬스터 카드를 무작위로 한 장 뽑는다.
YgoCard? _pickRandomMonster(
  List<YgoCard> from,
  Random r, {
  Set<int> excludeIds = const {},
}) {
  final candidates = from
      .where((c) => isMonsterCard(c) && _hasBattleStats(c) && !excludeIds.contains(c.id))
      .toList();
  if (candidates.isEmpty) return null;
  return candidates[r.nextInt(candidates.length)];
}

YgoCard? _pickRandomCard(
  List<YgoCard> from,
  Random r, {
  Set<int> excludeIds = const {},
}) {
  final candidates = from.where((c) => !excludeIds.contains(c.id)).toList();
  if (candidates.isEmpty) return null;
  return candidates[r.nextInt(candidates.length)];
}

int _statOf(YgoCard c, BattleMode mode) =>
    (mode == BattleMode.atk ? c.atk : c.def) ?? 0;

int _otherStatOf(YgoCard c, BattleMode mode) =>
    (mode == BattleMode.atk ? c.def : c.atk) ?? 0;

/// 한 라운드의 결과.
class JackpotRoundResult {
  /// 오늘의 타겟 카드 (보상 결정의 기준이 되는 카드).
  final YgoCard target;

  /// 실제로 출전한 카드. 타겟이 마법/함정이면 대타 몬스터가 들어간다.
  final YgoCard fighter;

  /// 대타가 출전했는지 여부.
  final bool isSubstitute;

  /// 상대 카드.
  final YgoCard opponent;

  /// ATK/DEF 비교로 승부를 가렸다면 그 모드. 스펠 스피드 비교라면 null.
  final BattleMode? mode;

  /// 진짜 무승부라서 3판 2승으로 넘어갔는지 여부.
  final bool wentToTiebreak;

  /// 이번 라운드를 이겼는지 여부 (보상 카드 지급의 기준).
  final bool won;

  const JackpotRoundResult({
    required this.target,
    required this.fighter,
    required this.isSubstitute,
    required this.opponent,
    required this.mode,
    required this.wentToTiebreak,
    required this.won,
  });
}

/// 3판 2승 동점자 결정전. 양쪽에 매번 새로운 무작위 몬스터를 부여해 승부를 가른다.
/// 진짜 무승부 라운드의 승패를 정하기 위한 것이라 "내 쪽"이 이겼는지만 반환한다.
bool _resolveBestOfThree(List<YgoCard> pool, Random r) {
  var sideAWins = 0;
  var sideBWins = 0;

  for (var i = 0; i < 3; i++) {
    final a = _pickRandomMonster(pool, r);
    final b = _pickRandomMonster(pool, r, excludeIds: a == null ? {} : {a.id});

    bool aWins;
    if (a == null || b == null) {
      aWins = r.nextBool();
    } else {
      final aAtk = a.atk ?? 0;
      final bAtk = b.atk ?? 0;
      if (aAtk != bAtk) {
        aWins = aAtk > bAtk;
      } else {
        final aDef = a.def ?? 0;
        final bDef = b.def ?? 0;
        aWins = aDef != bDef ? aDef > bDef : r.nextBool();
      }
    }

    if (aWins) {
      sideAWins++;
    } else {
      sideBWins++;
    }
    if (sideAWins == 2 || sideBWins == 2) break;
  }

  return sideAWins > sideBWins;
}

/// 한 라운드를 해석한다. [usedFighterIds]에는 이미 출전한 카드의 id를 누적해서
/// 같은 카드가 여러 라운드에 중복 출전하지 않도록 한다.
JackpotRoundResult resolveJackpotRound({
  required YgoCard target,
  required List<YgoCard> hand,
  required List<YgoCard> pool,
  required Set<int> usedFighterIds,
  required Random r,
}) {
  YgoCard fighter = target;
  var isSubstitute = false;

  if (!isMonsterCard(target) || !_hasBattleStats(target)) {
    final substitute = _pickRandomMonster(hand, r, excludeIds: usedFighterIds) ??
        _pickRandomMonster(pool, r, excludeIds: usedFighterIds);
    if (substitute != null) {
      fighter = substitute;
      isSubstitute = true;
    }
  }
  usedFighterIds.add(fighter.id);

  // 대타조차 구할 수 없는 극단적인 경우 → 스펠 스피드 등급 비교
  if (!isMonsterCard(fighter) || !_hasBattleStats(fighter)) {
    final opponent = _pickRandomCard(pool, r, excludeIds: {fighter.id}) ?? fighter;
    final myTier = spellSpeedTierOf(fighter);
    final opTier = spellSpeedTierOf(opponent);
    final won = myTier.index != opTier.index
        ? myTier.index > opTier.index
        : r.nextBool();

    return JackpotRoundResult(
      target: target,
      fighter: fighter,
      isSubstitute: isSubstitute,
      opponent: opponent,
      mode: null,
      wentToTiebreak: false,
      won: won,
    );
  }

  final opponent = _pickRandomMonster(pool, r, excludeIds: {fighter.id}) ??
      _pickRandomCard(pool, r, excludeIds: {fighter.id}) ??
      fighter;
  final mode = r.nextBool() ? BattleMode.atk : BattleMode.def;

  final myStat = _statOf(fighter, mode);
  final opStat = _statOf(opponent, mode);

  bool won;
  var wentToTiebreak = false;
  if (myStat != opStat) {
    won = myStat > opStat;
  } else {
    final myOther = _otherStatOf(fighter, mode);
    final opOther = _otherStatOf(opponent, mode);
    if (myOther != opOther) {
      won = myOther > opOther;
    } else {
      // 진짜 무승부 → 3판 2승
      wentToTiebreak = true;
      won = _resolveBestOfThree(pool, r);
    }
  }

  return JackpotRoundResult(
    target: target,
    fighter: fighter,
    isSubstitute: isSubstitute,
    opponent: opponent,
    mode: mode,
    wentToTiebreak: wentToTiebreak,
    won: won,
  );
}

/// 잭팟 배틀 전체 결과.
class JackpotBattleOutcome {
  final List<JackpotRoundResult> rounds;
  final List<YgoCard> rewardCards;
  final bool isConsolation;

  const JackpotBattleOutcome({
    required this.rounds,
    required this.rewardCards,
    required this.isConsolation,
  });

  int get wins => rounds.where((r) => r.won).length;
}

/// 잭팟으로 맞춘 타겟 3장이 순서대로 배틀하고, 승수에 따른 보상을 계산한다.
/// - 3승 → 타겟 카드 3장 모두 보상
/// - 2승 → 이긴 라운드의 타겟 카드 2장
/// - 1승 → 이긴 라운드의 타겟 카드 1장
/// - 0승 → 무작위 위안 카드 1장
JackpotBattleOutcome resolveJackpotBattle({
  required List<YgoCard> targets,
  required List<YgoCard> hand,
  required List<YgoCard> pool,
  required Random r,
}) {
  final usedFighterIds = <int>{};
  final rounds = <JackpotRoundResult>[];

  for (final target in targets) {
    rounds.add(resolveJackpotRound(
      target: target,
      hand: hand,
      pool: pool,
      usedFighterIds: usedFighterIds,
      r: r,
    ));
  }

  final wonTargets = rounds.where((r) => r.won).map((r) => r.target).toList();

  if (wonTargets.isNotEmpty) {
    return JackpotBattleOutcome(rounds: rounds, rewardCards: wonTargets, isConsolation: false);
  }

  final consolationSource = pool.isNotEmpty ? pool : hand;
  final consolation = _pickRandomCard(consolationSource, r) ?? targets.first;
  return JackpotBattleOutcome(
    rounds: rounds,
    rewardCards: [consolation],
    isConsolation: true,
  );
}
