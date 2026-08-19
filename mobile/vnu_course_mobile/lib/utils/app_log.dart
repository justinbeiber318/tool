import 'sanitizer.dart';

enum LogLevel { info, warning, error, debug }

class AppLogEntry {
  AppLogEntry({
    required this.timestamp,
    required this.level,
    required String message,
  }) : message = Sanitizer.sanitizeText(message);

  final DateTime timestamp;
  final LogLevel level;
  final String message;

  String get formatted {
    final time = [
      _two(timestamp.hour),
      _two(timestamp.minute),
      _two(timestamp.second),
    ].join(':');
    return '$time.${_three(timestamp.millisecond)} '
        '${level.label.padRight(9)} $message';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _three(int value) => value.toString().padLeft(3, '0');
}

extension LogLevelLabel on LogLevel {
  String get label {
    switch (this) {
      case LogLevel.info:
        return 'TIN';
      case LogLevel.warning:
        return 'CẢNH BÁO';
      case LogLevel.error:
        return 'LỖI';
      case LogLevel.debug:
        return 'GỠ LỖI';
    }
  }
}
