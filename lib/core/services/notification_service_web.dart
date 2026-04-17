import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('Notification')
extension type _Notif._(JSObject _) implements JSObject {
  external factory _Notif(String title, _NotifOpts opts);
  external static String get permission;
  external static JSPromise<JSString> requestPermission();
}

@JS()
@anonymous
extension type _NotifOpts._(JSObject _) implements JSObject {
  external factory _NotifOpts({String body});
}

class NotificationService {
  static bool get isSupported {
    try {
      _Notif.permission; // will throw if Notification not available
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getPermission() async {
    try {
      return _Notif.permission;
    } catch (_) {
      return 'denied';
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final result = await _Notif.requestPermission().toDart;
      return result.toDart == 'granted';
    } catch (e) {
      debugPrint('[Notification] requestPermission 실패: $e');
      return false;
    }
  }

  static Future<void> show(String title, {String? body}) async {
    try {
      final perm = _Notif.permission;
      if (perm != 'granted') return;
      _Notif(title, _NotifOpts(body: body ?? ''));
    } catch (e) {
      debugPrint('[Notification] show 실패: $e');
    }
  }

  static Future<void> showIfNotPlayedToday({required bool playedToday}) async {
    if (playedToday) return;
    await show(
      '🎴 오늘 뽑기를 잊지 마세요!',
      body: '지금 유희왕 슬롯에서 오늘의 타겟을 확인해보세요.',
    );
  }
}
