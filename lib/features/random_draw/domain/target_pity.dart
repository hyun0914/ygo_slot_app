import 'dart:math';

// -----------------------------
// 천장(피티) 시스템 — domain
//
// 오늘의 타겟 3장(전부 특정 카드)을 한 번의 뽑기에서 모두 맞히면 잭팟이다.
// 잭팟 없이 흘러간 뽑기 횟수(missCount)가 쌓이면, 부족한 타겟 카드를
// 보너스로 끼워 넣어줄 확률이 점점 올라가다가, 하드 천장에 도달하면
// 그날 부족한 타겟을 모두 채워 넣어 확정 잭팟을 만들어준다.
//
// 타겟은 매일 바뀌므로 missCount도 날짜(또는 타겟)가 바뀌면 0으로 리셋된다.
// -----------------------------

class TargetPityState {
  final String dateKey;

  /// 잭팟 없이 흘러간 뽑기 횟수 (오늘의 타겟이 바뀌면 0으로 리셋).
  final int missCount;

  /// 누적 잭팟 달성 횟수 (천장 보정 여부와 무관하게 누적).
  final int clearedCount;

  const TargetPityState({
    this.dateKey = '',
    this.missCount = 0,
    this.clearedCount = 0,
  });

  static const empty = TargetPityState();

  TargetPityState copyWith({
    String? dateKey,
    int? missCount,
    int? clearedCount,
  }) {
    return TargetPityState(
      dateKey: dateKey ?? this.dateKey,
      missCount: missCount ?? this.missCount,
      clearedCount: clearedCount ?? this.clearedCount,
    );
  }
}

// -----------------------------
// 천장 임계치
// -----------------------------

/// 이 미스 횟수부터 "부족한 타겟 보너스 주입" 확률이 붙기 시작한다 (소프트 천장).
const int kPitySoftStart = 200;

/// 이 미스 횟수에 도달하면 부족한 타겟을 모두 채워 넣어 확정 잭팟을 만든다 (하드 천장).
const int kPityHard = 500;

/// 현재 미스 횟수에 따라 "부족한 타겟 카드 한 장을 보너스로 끼워 넣을 확률"을 계산한다.
/// - kPitySoftStart 미만: 0% (순수 확률에 맡김)
/// - kPitySoftStart ~ kPityHard-1: 선형 증가
/// - kPityHard 이상: 100% (보장 — 부족한 타겟을 모두 채워 넣음)
double pityInjectionChance(int missCount) {
  if (missCount >= kPityHard) return 1.0;
  if (missCount < kPitySoftStart) return 0.0;

  final span = kPityHard - kPitySoftStart;
  final progressed = missCount - kPitySoftStart + 1;
  return progressed / span;
}

/// 천장 로직에 따라 부족한 타겟 카드 한 장을 이번 뽑기에 주입할지 결정한다.
bool shouldInjectPityTarget(int missCount, Random r) {
  final chance = pityInjectionChance(missCount);
  if (chance <= 0) return false;
  if (chance >= 1) return true;
  return r.nextDouble() < chance;
}

// -----------------------------
// 연속 뽑기 — 천장 포인트 베팅 미니게임
//
// 천장(missCount)을 "포인트"로 보고, 정해진 횟수만큼 한 번에 뽑는 동안
// 잭팟이 한 번이라도 터지면 승리(보너스 카드 획득), 못 터지면 건 만큼
// 포인트를 잃는 도박형 미니게임이다. 진행 중에는 일반 천장 증감을
// 적용하지 않고, 끝난 뒤 베팅 결과로 최종 포인트를 한 번에 정산한다.
// -----------------------------

/// 선택 가능한 연속 뽑기 횟수.
const List<int> kBatchBetSizes = [30, 50, 100, 150, 200, 250, 300, 350];

/// 연속 뽑기 횟수에 따라 걸어야 하는 천장 포인트.
int batchBetAmount(int batchSize) {
  if (batchSize <= 50) return 1;
  if (batchSize <= 150) return 2;
  if (batchSize <= 250) return 3;
  return 4;
}

/// 연속 뽑기 베팅 결과.
class BatchBetOutcome {
  final bool won;
  final int betAmount;
  final int pointsBefore;
  final int pointsAfter;

  /// 승리 시 추가로 지급되는 보너스 카드 장수.
  final int bonusCardCount;

  /// 4포인트 베팅 승리 시에는 포인트를 0으로 리셋하는 대신 2배로 불려준다.
  final bool pointsDoubled;

  const BatchBetOutcome({
    required this.won,
    required this.betAmount,
    required this.pointsBefore,
    required this.pointsAfter,
    required this.bonusCardCount,
    required this.pointsDoubled,
  });
}

/// 연속 뽑기 베팅 결과를 계산한다.
///
/// - 승리(잭팟 1회 이상 발생): 베팅액에 따라 보너스 카드 1~3장을 지급한다.
///   1~3포인트 베팅은 포인트를 0으로 리셋하고, 4포인트 베팅은 리셋 대신
///   "남은 포인트(걸고 남은 만큼, 없으면 베팅액)를 2배"로 불려준다.
/// - 패배(잭팟 없음): 포인트에서 베팅액만큼 차감한다 (0 미만으로는 내려가지 않음).
BatchBetOutcome resolveBatchBet({
  required int currentPoints,
  required int batchSize,
  required bool jackpotOccurred,
}) {
  final bet = batchBetAmount(batchSize);

  if (jackpotOccurred) {
    if (bet >= 4) {
      final remaining = currentPoints - bet;
      final base = remaining > 0 ? remaining : bet;
      return BatchBetOutcome(
        won: true,
        betAmount: bet,
        pointsBefore: currentPoints,
        pointsAfter: base * 2,
        bonusCardCount: 3,
        pointsDoubled: true,
      );
    }
    return BatchBetOutcome(
      won: true,
      betAmount: bet,
      pointsBefore: currentPoints,
      pointsAfter: 0,
      bonusCardCount: bet,
      pointsDoubled: false,
    );
  }

  final remaining = currentPoints - bet;
  return BatchBetOutcome(
    won: false,
    betAmount: bet,
    pointsBefore: currentPoints,
    pointsAfter: remaining > 0 ? remaining : 0,
    bonusCardCount: 0,
    pointsDoubled: false,
  );
}
