import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vnu_course_mobile/browser/desktop_mode.dart';

void main() {
  test('allows only VNU top-level https navigation', () {
    expect(
      DesktopMode.isAllowedTopLevelUrl('https://dangkyhoc.vnu.edu.vn/dang-nhap'),
      isTrue,
    );
    expect(
      DesktopMode.isAllowedTopLevelUrl('https://example.com/'),
      isFalse,
    );
  });

  test('uses desktop user agents', () {
    expect(
      DesktopMode.userAgentFor(TargetPlatform.android),
      contains('Windows NT 10.0'),
    );
    expect(
      DesktopMode.userAgentFor(TargetPlatform.iOS),
      contains('Macintosh'),
    );
  });
}
