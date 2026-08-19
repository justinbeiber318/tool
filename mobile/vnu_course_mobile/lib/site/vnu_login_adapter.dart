import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../browser/desktop_mode.dart';
import 'vnu_login_selectors.dart';

class VnuLoginStatus {
  const VnuLoginStatus({
    required this.loggedIn,
    required this.captchaRequired,
    required this.loginErrorText,
  });

  final bool loggedIn;
  final bool captchaRequired;
  final String loginErrorText;
}

class VnuLoginAdapter {
  VnuLoginAdapter({this.selectors = const VnuLoginSelectors()});

  final VnuLoginSelectors selectors;

  Future<void> fillCredentials(
    WebViewController controller, {
    required String username,
    required String password,
  }) async {
    await _assertAllowedHost(controller);
    final result = await controller.runJavaScriptReturningResult('''
(() => {
  const first = (selectors) => {
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      if (element) return element;
    }
    return null;
  };

  const setNativeValue = (element, value) => {
    const prototype = Object.getPrototypeOf(element);
    const descriptor = Object.getOwnPropertyDescriptor(prototype, 'value');
    if (descriptor && descriptor.set) {
      descriptor.set.call(element, value);
    } else {
      element.value = value;
    }
    element.dispatchEvent(new Event('input', { bubbles: true }));
    element.dispatchEvent(new Event('change', { bubbles: true }));
  };

  const username = first(${jsonEncode(selectors.username)});
  const password = first(${jsonEncode(selectors.password)});
  if (!username || !password) {
    return false;
  }
  setNativeValue(username, ${jsonEncode(username)});
  setNativeValue(password, ${jsonEncode(password)});
  return true;
})();
''');
    if (result != true && result.toString() != 'true') {
      throw StateError('Không tìm thấy ô đăng nhập.');
    }
  }

  Future<VnuLoginStatus> probeStatus(WebViewController controller) async {
    await _assertAllowedHost(controller);
    final result = await controller.runJavaScriptReturningResult('''
(() => {
  const any = (selectors) => selectors.some(
    (selector) => document.querySelector(selector) !== null
  );
  const text = (selectors) => {
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      if (element && element.innerText && element.innerText.trim()) {
        return element.innerText.trim();
      }
    }
    return '';
  };
  const bodyText = document.body ? document.body.innerText.toLowerCase() : '';
  const loggedIn =
    any(${jsonEncode(selectors.loggedInMarkers)}) ||
    bodyText.includes('dang xuat');
  const captchaRequired =
    any(${jsonEncode(selectors.captchaMarkers)}) ||
    bodyText.includes('turnstile') ||
    bodyText.includes('captcha') ||
    bodyText.includes('xac minh') ||
    bodyText.includes('verify');
  return JSON.stringify({
    loggedIn,
    captchaRequired,
    loginErrorText: text(${jsonEncode(selectors.loginErrors)})
  });
})();
''');
    return _parseStatus(result);
  }

  Future<void> _assertAllowedHost(WebViewController controller) async {
    final url = await controller.currentUrl();
    if (url == null || !DesktopMode.isAllowedTopLevelUrl(url)) {
      throw StateError('Tự động hóa tạm dừng: trang hiện tại không hợp lệ.');
    }
  }

  VnuLoginStatus _parseStatus(Object value) {
    final raw = value.toString();
    final normalized = raw.length >= 2 && raw.startsWith('"')
        ? jsonDecode(raw) as String
        : raw;
    final decoded = jsonDecode(normalized) as Map<String, dynamic>;
    return VnuLoginStatus(
      loggedIn: decoded['loggedIn'] == true,
      captchaRequired: decoded['captchaRequired'] == true,
      loginErrorText: (decoded['loginErrorText'] as String? ?? '').trim(),
    );
  }
}
