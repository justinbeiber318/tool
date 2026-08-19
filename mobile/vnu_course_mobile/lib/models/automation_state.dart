enum AutomationState {
  idle,
  openingLoginPage,
  fillingCredentials,
  captchaRequired,
  waitingLogin,
  loginSuccess,
  checkingSession,
  registeringCourse,
  courseRegistered,
  sessionExpired,
  failed,
  stopped,
}

extension AutomationStateLabel on AutomationState {
  String get label {
    switch (this) {
      case AutomationState.idle:
        return 'CHỜ';
      case AutomationState.openingLoginPage:
        return 'MỞ ĐĂNG NHẬP';
      case AutomationState.fillingCredentials:
        return 'TỰ ĐIỀN';
      case AutomationState.captchaRequired:
        return 'CẦN CAPTCHA';
      case AutomationState.waitingLogin:
        return 'CHỜ ĐĂNG NHẬP';
      case AutomationState.loginSuccess:
        return 'ĐÃ ĐĂNG NHẬP';
      case AutomationState.checkingSession:
        return 'KIỂM TRA PHIÊN';
      case AutomationState.registeringCourse:
        return 'ĐĂNG KÝ MÔN';
      case AutomationState.courseRegistered:
        return 'ĐÃ BẤM ĐĂNG';
      case AutomationState.sessionExpired:
        return 'HẾT PHIÊN';
      case AutomationState.failed:
        return 'LỖI';
      case AutomationState.stopped:
        return 'ĐÃ DỪNG';
    }
  }
}
