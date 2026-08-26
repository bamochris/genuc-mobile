import 'package:flutter/foundation.dart';

class Logger {
  static void d(String tag, String message) {
    debugPrint('[$tag] $message');
  }

  static void e(String tag, String message, [Object? error]) {
    debugPrint('[$tag] ERROR: $message ${error ?? ''}');
  }
}
