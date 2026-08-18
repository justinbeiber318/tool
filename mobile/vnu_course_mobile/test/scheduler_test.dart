import 'package:flutter_test/flutter_test.dart';
import 'package:vnu_course_mobile/automation/scheduler.dart';

void main() {
  test('uses lower sleep intervals near target', () {
    expect(
      nextSleepInterval(const Duration(seconds: 90)),
      const Duration(seconds: 1),
    );
    expect(
      nextSleepInterval(const Duration(seconds: 30)),
      const Duration(milliseconds: 200),
    );
    expect(
      nextSleepInterval(const Duration(seconds: 4)),
      const Duration(milliseconds: 50),
    );
  });

  test('detects wall clock jumps against monotonic elapsed', () {
    final previous = SchedulerClockSnapshot(
      wallClock: DateTime(2026, 8, 18, 8),
      monotonicElapsed: Duration.zero,
    );
    final current = SchedulerClockSnapshot(
      wallClock: DateTime(2026, 8, 18, 8, 0, 10),
      monotonicElapsed: const Duration(seconds: 1),
    );

    expect(
      clockJumpDetected(previous: previous, current: current),
      isTrue,
    );
  });
}
