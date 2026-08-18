import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/session_info.dart';

class SessionService {
  SessionService({
    this.sessionTtl = const Duration(minutes: 20),
  });

  final Duration sessionTtl;
  final ValueNotifier<SessionInfo?> session = ValueNotifier<SessionInfo?>(null);
  final ValueNotifier<Duration> remaining =
      ValueNotifier<Duration>(Duration.zero);

  Timer? _timer;

  void markLoggedIn(DateTime loginTime) {
    final info = SessionInfo(
      loginTime: loginTime,
      expiresAt: loginTime.add(sessionTtl),
    );
    session.value = info;
    _startTimer();
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    session.value = null;
    remaining.value = Duration.zero;
  }

  bool get isActive {
    final info = session.value;
    return info != null && !info.isExpired;
  }

  void dispose() {
    clear();
    session.dispose();
    remaining.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final info = session.value;
    if (info == null) {
      remaining.value = Duration.zero;
      return;
    }
    remaining.value = info.remaining(DateTime.now());
    if (remaining.value == Duration.zero) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
