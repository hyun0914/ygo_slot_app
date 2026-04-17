class NotificationService {
  static bool get isSupported => false;
  static Future<bool> requestPermission() async => false;
  static Future<String> getPermission() async => 'denied';
  static Future<void> show(String title, {String? body}) async {}
  static Future<void> showIfNotPlayedToday({required bool playedToday}) async {}
}
