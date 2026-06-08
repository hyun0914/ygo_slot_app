class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.unlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({bool? unlocked, DateTime? unlockedAt}) => Achievement(
        id: id,
        title: title,
        description: description,
        emoji: emoji,
        unlocked: unlocked ?? this.unlocked,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );
}

// All achievement definitions (unlocked/unlockedAt always false/null at definition time)
const kAllAchievements = [
  Achievement(id: 'first_draw',        title: '첫 뽑기',       description: '처음으로 카드를 뽑았습니다',         emoji: '🎴'),
  Achievement(id: 'first_hit',         title: '첫 히트',       description: '처음으로 목표 달성!',                emoji: '🎯'),
  Achievement(id: 'first_jackpot',     title: '첫 잭팟',       description: '처음으로 3히트 잭팟!',               emoji: '🎰'),
  Achievement(id: 'boss_jackpot',      title: '보스 격파',     description: '보스 데이 잭팟 달성!',               emoji: '👑'),
  Achievement(id: 'streak_3',          title: '3연속 잭팟',    description: '3일 연속 잭팟!',                     emoji: '🔥'),
  Achievement(id: 'streak_7',          title: '7연속 잭팟',    description: '7일 연속 잭팟!',                     emoji: '⚡'),
  Achievement(id: 'streak_30',         title: '전설의 연속',   description: '30일 연속 잭팟!',                    emoji: '🌟'),
  Achievement(id: 'draws_10',          title: '10번 도전',     description: '총 10번 뽑기 완료',                  emoji: '💪'),
  Achievement(id: 'draws_100',         title: '100번 도전',    description: '총 100번 뽑기 완료',                 emoji: '🏅'),
  Achievement(id: 'draws_1000',        title: '천 번의 도전',  description: '총 1000번 뽑기 완료',                emoji: '🏆'),
  Achievement(id: 'jackpots_5',        title: '잭팟 마스터',   description: '누적 잭팟 5회',                      emoji: '⭐'),
  Achievement(id: 'jackpots_10',       title: '잭팟 전문가',   description: '누적 잭팟 10회',                     emoji: '🌠'),
  Achievement(id: 'jackpots_50',       title: '잭팟의 신',     description: '누적 잭팟 50회',                     emoji: '✨'),
  Achievement(id: 'batch_first',       title: '연속 뽑기',     description: '첫 배치 뽑기 완료',                  emoji: '🎲'),
  Achievement(id: 'challenge_jackpot', title: '챌린지 정복',   description: '챌린지 모드 (3장) 잭팟',             emoji: '⚔️'),
  Achievement(id: 'comfort_jackpot',   title: '여유로운 승리', description: '컴포트 모드 (7장) 잭팟',             emoji: '🛋️'),
  Achievement(id: 'collection_5',      title: '전리품 시작',   description: '전리품 5종 수집',                    emoji: '📚'),
  Achievement(id: 'collection_20',     title: '중급 수집가',   description: '전리품 20종 수집',                   emoji: '📖'),
  Achievement(id: 'collection_50',     title: '베테랑 수집가', description: '전리품 50종 수집',                   emoji: '📕'),
];
