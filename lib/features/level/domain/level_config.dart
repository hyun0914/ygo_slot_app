// XP thresholds: index = level-1, value = total XP needed to reach that level
const kXpThresholds = <int>[
  0,     // Lv 1
  100,   // Lv 2
  250,   // Lv 3
  500,   // Lv 4
  900,   // Lv 5
  1500,  // Lv 6
  2500,  // Lv 7
  4000,  // Lv 8
  6000,  // Lv 9
  9000,  // Lv 10
  13000, // Lv 11
  18000, // Lv 12
  25000, // Lv 13
  35000, // Lv 14
  50000, // Lv 15 (max)
];

const int kMaxLevel = 15;

/// Returns level (1-based) for given total XP.
int xpToLevel(int xp) {
  for (int i = kXpThresholds.length - 1; i >= 0; i--) {
    if (xp >= kXpThresholds[i]) return i + 1;
  }
  return 1;
}

/// XP required to reach next level (0 if already max).
int xpToNextLevel(int xp) {
  final lv = xpToLevel(xp);
  if (lv >= kMaxLevel) return 0;
  return kXpThresholds[lv] - xp;
}

/// XP range for current level band.
({int min, int max}) xpBand(int xp) {
  final lv = xpToLevel(xp);
  final min = kXpThresholds[lv - 1];
  final max = lv >= kMaxLevel ? kXpThresholds.last : kXpThresholds[lv];
  return (min: min, max: max);
}

String levelTitle(int level) {
  if (level <= 2) return '뉴비 결투자';
  if (level <= 4) return '초보 결투자';
  if (level <= 6) return '유망주';
  if (level <= 8) return '정식 결투자';
  if (level <= 10) return '숙련 결투자';
  if (level <= 12) return '엘리트';
  if (level <= 14) return '챔피언';
  return '전설의 결투자';
}

String levelEmoji(int level) {
  if (level <= 2) return '🌱';
  if (level <= 4) return '🌿';
  if (level <= 6) return '⚡';
  if (level <= 8) return '🔥';
  if (level <= 10) return '💎';
  if (level <= 12) return '👑';
  if (level <= 14) return '🌟';
  return '✨';
}

// XP awards
const int kXpPerDraw = 5;
const int kXpPerHit1 = 15;
const int kXpPerHit2 = 30;
const int kXpPerJackpot = 60;
const int kXpPerBossJackpot = 120;
const int kXpBatchBonus = 10;

int calcXpGain({required int hits, required bool bossJackpot, bool isBatch = false}) {
  int xp = kXpPerDraw;
  if (hits == 1) xp += kXpPerHit1;
  if (hits == 2) xp += kXpPerHit2;
  if (hits >= 3) {
    xp += bossJackpot ? kXpPerBossJackpot : kXpPerJackpot;
  }
  if (isBatch) xp += kXpBatchBonus;
  return xp;
}
