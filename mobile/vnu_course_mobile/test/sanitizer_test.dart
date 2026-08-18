import 'package:flutter_test/flutter_test.dart';
import 'package:vnu_course_mobile/utils/sanitizer.dart';

void main() {
  test('redacts sensitive log lines', () {
    final sanitized = Sanitizer.sanitizeText(
      'username=22000001\npassword=secret\nCookie: abc',
    );

    expect(sanitized, contains('username=22000001'));
    expect(sanitized, isNot(contains('secret')));
    expect(sanitized, contains('[redacted]'));
  });

  test('masks username like the desktop utility', () {
    expect(Sanitizer.maskUsername('22000008'), '2***8');
    expect(Sanitizer.maskUsername('ab'), '**');
  });

  test('redacts sensitive URL parameters', () {
    final sanitized = Sanitizer.sanitizeUrl(
      'https://dangkyhoc.vnu.edu.vn/dang-nhap?token=abc&next=/home',
    );

    expect(sanitized, contains('token=%5Bredacted%5D'));
    expect(sanitized, contains('next=%2Fhome'));
  });
}
