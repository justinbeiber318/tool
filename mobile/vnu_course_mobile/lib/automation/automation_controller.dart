import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../browser/persistent_webview_controller.dart';
import '../models/automation_state.dart';
import '../services/session_service.dart';
import '../site/vnu_login_adapter.dart';
import '../utils/app_log.dart';
import '../utils/sanitizer.dart';

class AutomationController {
  AutomationController({
    required this.webView,
    VnuLoginAdapter? loginAdapter,
    SessionService? sessionService,
  })  : loginAdapter = loginAdapter ?? VnuLoginAdapter(),
        sessionService = sessionService ?? SessionService();

  final PersistentWebViewController webView;
  final VnuLoginAdapter loginAdapter;
  final SessionService sessionService;

  final ValueNotifier<AutomationState> state =
      ValueNotifier<AutomationState>(AutomationState.idle);
  final ValueNotifier<String> task = ValueNotifier<String>('Ready');

  Future<void> openLoginTest() async {
    _transition(AutomationState.openingLoginPage, 'Opening login page');
    await webView.openLoginTest();
    _transition(AutomationState.waitingLogin, 'Waiting for manual login');
  }

  Future<void> fillCredentials({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      _transition(AutomationState.failed, 'Username/password is required');
      return;
    }

    try {
      _transition(AutomationState.fillingCredentials, 'Filling credentials');
      await loginAdapter.fillCredentials(
        webView.controller,
        username: username.trim(),
        password: password,
      );
      final status = await loginAdapter.probeStatus(webView.controller);
      if (status.captchaRequired) {
        await _setKeepAwake(true);
        _transition(
          AutomationState.captchaRequired,
          'CAPTCHA required; user must verify manually in this WebView',
        );
        return;
      }
      _transition(AutomationState.waitingLogin, 'Credentials filled');
    } catch (error) {
      _transition(AutomationState.failed, error.toString());
    }
  }

  Future<void> checkLoginStatus() async {
    try {
      _transition(AutomationState.checkingSession, 'Checking login status');
      final status = await loginAdapter.probeStatus(webView.controller);
      if (status.loggedIn) {
        final now = DateTime.now();
        sessionService.markLoggedIn(now);
        await _setKeepAwake(false);
        _transition(
          AutomationState.loginSuccess,
          'Login confirmed at ${_time(now)}',
        );
        webView.addLog(LogLevel.info, 'Logged in as current WebView user.');
        return;
      }
      if (status.loginErrorText.isNotEmpty) {
        _transition(
          AutomationState.failed,
          Sanitizer.sanitizeText(status.loginErrorText),
        );
        return;
      }
      if (status.captchaRequired) {
        await _setKeepAwake(true);
        _transition(
          AutomationState.captchaRequired,
          'CAPTCHA still required',
        );
        return;
      }
      _transition(AutomationState.waitingLogin, 'Login not confirmed yet');
    } catch (error) {
      _transition(AutomationState.failed, error.toString());
    }
  }

  Future<void> stop() async {
    sessionService.clear();
    await _setKeepAwake(false);
    _transition(AutomationState.stopped, 'Stopped');
  }

  void dispose() {
    state.dispose();
    task.dispose();
    sessionService.dispose();
  }

  void _transition(AutomationState next, String nextTask) {
    state.value = next;
    task.value = Sanitizer.sanitizeText(nextTask);
    webView.addLog(LogLevel.info, '${next.label}: $nextTask');
  }

  Future<void> _setKeepAwake(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
      webView.addLog(
        LogLevel.debug,
        "Keep screen awake ${enabled ? 'enabled' : 'disabled'}.",
      );
    } catch (error) {
      webView.addLog(LogLevel.warning, 'Could not update wakelock: $error');
    }
  }

  String _time(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }
}
