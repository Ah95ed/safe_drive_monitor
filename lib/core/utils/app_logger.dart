import 'package:flutter/foundation.dart';

/// Lightweight structured logger that only prints in debug mode.
/// Avoids dumping frame buffers or huge memory dumps.
class AppLogger {
  AppLogger._();

  static void debug(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG][$tag] $message');
    }
  }

  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[INFO][$tag] $message');
    }
  }

  static void warning(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[WARN][$tag] $message');
    }
  }

  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR][$tag] $message');
      if (error != null) {
        debugPrint('[ERROR][$tag] Details: $error');
      }
      if (stackTrace != null) {
        debugPrint('[ERROR][$tag] Stack: $stackTrace');
      }
    }
  }
}
