enum AutomationState {
  idle,
  openingLoginPage,
  fillingCredentials,
  captchaRequired,
  waitingLogin,
  loginSuccess,
  checkingSession,
  sessionExpired,
  failed,
  stopped,
}

extension AutomationStateLabel on AutomationState {
  String get label {
    switch (this) {
      case AutomationState.idle:
        return 'IDLE';
      case AutomationState.openingLoginPage:
        return 'OPENING_LOGIN_PAGE';
      case AutomationState.fillingCredentials:
        return 'FILLING_CREDENTIALS';
      case AutomationState.captchaRequired:
        return 'CAPTCHA_REQUIRED';
      case AutomationState.waitingLogin:
        return 'WAITING_LOGIN';
      case AutomationState.loginSuccess:
        return 'LOGIN_SUCCESS';
      case AutomationState.checkingSession:
        return 'CHECKING_SESSION';
      case AutomationState.sessionExpired:
        return 'SESSION_EXPIRED';
      case AutomationState.failed:
        return 'FAILED';
      case AutomationState.stopped:
        return 'STOPPED';
    }
  }
}
