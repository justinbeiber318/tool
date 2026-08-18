class PreloginConfig {
  const PreloginConfig({
    this.sessionTtl = const Duration(minutes: 20),
    this.expectedRegistrationDuration = const Duration(minutes: 5),
    this.safetyMargin = const Duration(minutes: 2),
    this.preloginOffset = const Duration(minutes: 13),
  });

  final Duration sessionTtl;
  final Duration expectedRegistrationDuration;
  final Duration safetyMargin;
  final Duration preloginOffset;

  Duration get maxSafePrelogin {
    final value = sessionTtl - expectedRegistrationDuration - safetyMargin;
    return value.isNegative ? Duration.zero : value;
  }

  DateTime loginAt(DateTime registrationTime) {
    return registrationTime.subtract(preloginOffset);
  }

  DateTime expiresAt(DateTime registrationTime) {
    return loginAt(registrationTime).add(sessionTtl);
  }

  Duration remainingAfterOpen(DateTime registrationTime) {
    final value = expiresAt(registrationTime).difference(registrationTime);
    return value.isNegative ? Duration.zero : value;
  }

  bool get isTooEarly => preloginOffset > maxSafePrelogin;
}
