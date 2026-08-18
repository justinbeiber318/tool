import 'package:flutter_test/flutter_test.dart';
import 'package:vnu_course_mobile/models/prelogin_config.dart';

void main() {
  test('calculates max safe prelogin from session budget', () {
    const config = PreloginConfig();

    expect(config.maxSafePrelogin, const Duration(minutes: 13));
  });

  test('warns when selected prelogin is too early', () {
    const config = PreloginConfig(preloginOffset: Duration(minutes: 15));

    expect(config.isTooEarly, isTrue);
  });
}
