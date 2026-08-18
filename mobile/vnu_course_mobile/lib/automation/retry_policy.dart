class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 2,
    this.delays = const <Duration>[
      Duration(milliseconds: 200),
      Duration(milliseconds: 500),
    ],
  });

  final int maxRetries;
  final List<Duration> delays;

  Duration delayForRetry(int retryIndex) {
    if (retryIndex < 0 || retryIndex >= delays.length) {
      return Duration.zero;
    }
    return delays[retryIndex];
  }
}
