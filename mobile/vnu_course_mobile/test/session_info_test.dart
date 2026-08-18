import 'package:flutter_test/flutter_test.dart';
import 'package:vnu_course_mobile/models/session_info.dart';

void main() {
  test('calculates remaining session time', () {
    final login = DateTime(2026, 8, 18, 7, 47);
    final session = SessionInfo(
      loginTime: login,
      expiresAt: login.add(const Duration(minutes: 20)),
    );

    expect(
      session.remaining(DateTime(2026, 8, 18, 8)),
      const Duration(minutes: 7),
    );
  });
}
