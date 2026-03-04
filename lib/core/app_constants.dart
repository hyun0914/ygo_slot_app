/// 앱 전역 상수 모음
abstract final class AppConstants {
  // 유희왕 카드 이미지 비율 (실물 카드 규격 59mm x 86mm)
  static const double ygoCardAspectRatio = 59 / 86;

  // 슬롯 릴 애니메이션
  static const Duration reelTickInterval = Duration(milliseconds: 55);
  static const Duration reelStopInterval = Duration(milliseconds: 90);
  static const Duration reelScrollDuration = Duration(milliseconds: 260);
  static const Duration batchDrawDelay = Duration(milliseconds: 140);
  static const Duration cardFadeOut = Duration(milliseconds: 120);

  // 스켈레톤 shimmer
  static const Duration shimmerDuration = Duration(milliseconds: 1200);

  // 데일리 풀 크기
  static const int dailyPoolSize = 200;
}
