import 'package:flutter/foundation.dart';

class DesktopMode {
  static const String vnuLoginUrl = 'https://dangkyhoc.vnu.edu.vn/dang-nhap';
  static const String allowedHost = 'dangkyhoc.vnu.edu.vn';

  static String userAgentFor(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Version/18.0 Safari/605.1.15';
    }

    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/126.0.0.0 Safari/537.36';
  }

  static bool isAllowedTopLevelUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    if (uri.scheme == 'about') {
      return true;
    }
    return uri.scheme == 'https' && uri.host == allowedHost;
  }
}
