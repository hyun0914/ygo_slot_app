class SoundService {
  static bool _muted = false;
  static bool get muted => _muted;
  static void toggleMute() => _muted = !_muted;

  static void playSpinStart() {}
  static void playReelTick() {}
  static void playHit() {}
  static void playJackpot() {}
  static void playBossJackpot() {}
}
