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
        '${level.name.toUpperCase().padRight(7)} $message';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _three(int value) => value.toString().padLeft(3, '0');
}
