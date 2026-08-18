class SchedulerClockSnapshot {
  const SchedulerClockSnapshot({
    required this.wallClock,
    required this.monotonicElapsed,
  });

  final DateTime wallClock;
  final Duration monotonicElapsed;
}

Duration nextSleepInterval(Duration remaining) {
  if (remaining > const Duration(seconds: 60)) {
    return const Duration(seconds: 1);
  }
  if (remaining > const Duration(seconds: 5)) {
    return const Duration(milliseconds: 200);
  }
  return const Duration(milliseconds: 50);
}

bool clockJumpDetected({
  required SchedulerClockSnapshot previous,
  required SchedulerClockSnapshot current,
  Duration threshold = const Duration(seconds: 2),
}) {
  final wallDelta = current.wallClock.difference(previous.wallClock).abs();
  final monoDelta = current.monotonicElapsed - previous.monotonicElapsed;
  final drift = wallDelta - monoDelta.abs();
  return drift.abs() > threshold;
}
