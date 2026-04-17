import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('navigator.clipboard.writeText')
external JSPromise<JSAny?> _writeText(String text);

class ShareService {
  static bool get isClipboardSupported => true;

  static Future<bool> copyToClipboard(String text) async {
    try {
      await _writeText(text).toDart;
      return true;
    } catch (e) {
      debugPrint('[Share] 클립보드 복사 실패: $e');
      return false;
    }
  }
}
