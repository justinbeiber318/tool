import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../browser/persistent_webview_controller.dart';
import '../models/automation_state.dart';
import '../services/session_service.dart';
import '../site/vnu_login_adapter.dart';
import '../site/vnu_registration_adapter.dart';
import '../utils/app_log.dart';
import '../utils/sanitizer.dart';

class AutomationController {
  AutomationController({
    required this.webView,
    VnuLoginAdapter? loginAdapter,
    VnuRegistrationAdapter? registrationAdapter,
    SessionService? sessionService,
  }) : loginAdapter = loginAdapter ?? VnuLoginAdapter(),
       registrationAdapter = registrationAdapter ?? VnuRegistrationAdapter(),
       sessionService = sessionService ?? SessionService();

  final PersistentWebViewController webView;
  final VnuLoginAdapter loginAdapter;
  final VnuRegistrationAdapter registrationAdapter;
  final SessionService sessionService;

  final ValueNotifier<AutomationState> state = ValueNotifier<AutomationState>(
    AutomationState.idle,
  );
  final ValueNotifier<String> task = ValueNotifier<String>('Sẵn sàng');

  Future<void> openLoginTest() async {
    _transition(AutomationState.openingLoginPage, 'Đang mở trang đăng nhập');
    await webView.openLoginTest();
    _transition(AutomationState.waitingLogin, 'Chờ bạn đăng nhập thủ công');
  }

  Future<void> fillCredentials({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      _transition(AutomationState.failed, 'Cần nhập tên truy cập và mật khẩu');
      return;
    }

    try {
      _transition(AutomationState.fillingCredentials, 'Đang tự điền tài khoản');
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
          'Cần xác minh CAPTCHA thủ công trong trình duyệt này',
        );
        return;
      }
      _transition(AutomationState.waitingLogin, 'Đã điền tài khoản');
    } catch (error) {
      _transition(AutomationState.failed, error.toString());
    }
  }

  Future<void> checkLoginStatus() async {
    try {
      _transition(AutomationState.checkingSession, 'Đang kiểm tra đăng nhập');
      final status = await loginAdapter.probeStatus(webView.controller);
      if (status.loggedIn) {
        final now = DateTime.now();
        sessionService.markLoggedIn(now);
        await _setKeepAwake(false);
        _transition(
          AutomationState.loginSuccess,
          'Đã xác nhận đăng nhập lúc ${_time(now)}',
        );
        webView.addLog(
          LogLevel.info,
          'Đã đăng nhập trong phiên trình duyệt hiện tại.',
        );
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
          'Vẫn cần xác minh CAPTCHA',
        );
        return;
      }
      _transition(AutomationState.waitingLogin, 'Chưa xác nhận được đăng nhập');
    } catch (error) {
      _transition(AutomationState.failed, error.toString());
    }
  }

  Future<void> registerCourse({required String classCode}) async {
    final target = classCode.trim();
    if (target.isEmpty) {
      _transition(AutomationState.failed, 'Cần nhập mã lớp môn học');
      return;
    }

    try {
      _transition(AutomationState.registeringCourse, 'Đang tìm lớp $target');
      final result = await registrationAdapter.registerCourse(
        webView.controller,
        classCode: target,
      );
      webView.addLog(LogLevel.info, Sanitizer.sanitizeText(result.rowText));
      switch (result.status) {
        case VnuRegistrationStatus.clicked:
          _transition(
            AutomationState.courseRegistered,
            Sanitizer.sanitizeText(result.message),
          );
        case VnuRegistrationStatus.notFound:
        case VnuRegistrationStatus.ambiguous:
        case VnuRegistrationStatus.actionNotFound:
        case VnuRegistrationStatus.wrongPage:
          _transition(
            AutomationState.failed,
            Sanitizer.sanitizeText(result.message),
          );
      }
    } catch (error) {
      _transition(AutomationState.failed, error.toString());
    }
  }

  Future<void> stop() async {
    sessionService.clear();
    await _setKeepAwake(false);
    _transition(AutomationState.stopped, 'Đã dừng');
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
        'Giữ màn hình sáng: ${enabled ? 'bật' : 'tắt'}.',
      );
    } catch (error) {
      webView.addLog(LogLevel.warning, 'Không thể cập nhật wakelock: $error');
    }
  }

  String _time(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }
}
