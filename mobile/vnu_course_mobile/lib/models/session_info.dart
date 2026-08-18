class SessionInfo {
  const SessionInfo({
    required this.loginTime,
    required this.expiresAt,
  });

  final DateTime loginTime;
  final DateTime expiresAt;

  Duration remaining(DateTime now) {
    final value = expiresAt.difference(now);
    return value.isNegative ? Duration.zero : value;
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
