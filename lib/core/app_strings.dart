/// 앱 UI 문자열 상수 모음
abstract final class AppStrings {
  // 뽑기 모드 레이블
  static const String modeChallenge = '도전(3장)';
  static const String modeDefault = '기본(5장)';
  static const String modeComfort = '편안(7장)';

  static const String modeChallengeTitle = '도전 모드 (3장)';
  static const String modeDefaultTitle = '기본 모드 (5장)';
  static const String modeComfortTitle = '편안 모드 (7장)';

  static const String modeChallengeDesc = '짧고 날카롭게. 잭팟이 진짜 어렵다 🔥';
  static const String modeDefaultDesc = '딱 맞는 밸런스 🎰';
  static const String modeComfortDesc = '조금 더 자주 맞추고 싶은 날 🏆';

  static const String modePickerTitle = '모드 선택';
  static const String modePickerSubtitle = '카드 수를 고정 모드로 단순화했어. (3/5/7)';
  static const String modeResetButton = '기본(5)로';
  static const String applyButton = '적용';

  // 랜딩
  static const String appTitle = '유희왕 슬롯';
  static const String appSubtitle = '데일리 슬롯 룰은 하루 동안 고정돼요.';
  static const String startButton = '🔥 바로 시작';
  static const String loadingButton = '🎲 준비중...';
  static const String settingsButton = '⚙️ 카드 수 설정';

  // 에러 화면
  static const String retryButton = '다시 시도';

  // 슬롯 헤더
  static const String headerLoading = '오늘의 슬롯 타겟 준비 중… (첫 뽑기 후 고정)';

  // 뽑기 버튼
  static const String drawButton = '🎲 랜덤 뽑기';
  static const String drawingButton = '🎲 뽑는 중...';

  // 배치 뽑기
  static const String batchStartButton = '연속 뽑기';
  static const String batchStopButton = '연속뽑기 중단';

  // 보드 상태
  static const String initialPrompt = '버튼 한 번 누르고\n뭐 나오는지 보자 😎';
  static const String emptyCardMessage = '카드가 없어요.\n다시 뽑아볼까요?';
  static const String redrawButton = '다시 뽑기';
  static const String confirmButton = '확인';
}
