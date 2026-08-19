import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../utils/app_log.dart';
import '../utils/sanitizer.dart';
import 'desktop_mode.dart';

class PersistentWebViewController {
  PersistentWebViewController({
    required this.loginUrl,
    required this.allowedHost,
  });

  factory PersistentWebViewController.loginTest() {
    return PersistentWebViewController(
      loginUrl: Uri.parse(DesktopMode.vnuLoginUrl),
      allowedHost: DesktopMode.allowedHost,
    );
  }

  final Uri loginUrl;
  final String allowedHost;

  final ValueNotifier<String> currentUrl = ValueNotifier<String>('chưa tải');
  final ValueNotifier<int> progress = ValueNotifier<int>(0);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<List<AppLogEntry>> logs =
      ValueNotifier<List<AppLogEntry>>(<AppLogEntry>[]);

  WebViewController? _controller;
  bool _initialized = false;

  WebViewController get controller {
    final active = _controller;
    if (active == null) {
      throw StateError('Trình duyệt chưa được khởi tạo.');
    }
    return active;
  }

  Future<void> openLoginTest() async {
    await initialize();
    addLog(LogLevel.info, 'Đang mở trang đăng nhập: ${loginUrl.host}');
    await controller.loadRequest(loginUrl);
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final webViewController = WebViewController.fromPlatformCreationParams(
      params,
    );
    _controller = webViewController;

    await webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webViewController.setUserAgent(
      DesktopMode.userAgentFor(defaultTargetPlatform),
    );
    await webViewController.enableZoom(true);
    await webViewController.setBackgroundColor(Colors.white);
    await webViewController.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (value) => progress.value = value,
        onPageStarted: (url) {
          isLoading.value = true;
          _setCurrentUrl(url);
          addLog(LogLevel.info, 'Bắt đầu tải ${Sanitizer.sanitizeUrl(url)}');
        },
        onPageFinished: (url) {
          isLoading.value = false;
          progress.value = 100;
          _setCurrentUrl(url);
          addLog(LogLevel.info, 'Tải xong ${Sanitizer.sanitizeUrl(url)}');
        },
        onUrlChange: (change) {
          final url = change.url;
          if (url != null) {
            _setCurrentUrl(url);
          }
        },
        onWebResourceError: (error) {
          addLog(
            LogLevel.warning,
            'Lỗi tài nguyên web ${error.errorCode}: ${error.description}',
          );
        },
        onNavigationRequest: (request) {
          if (!DesktopMode.isAllowedTopLevelUrl(request.url)) {
            addLog(
              LogLevel.warning,
              'Phát hiện điều hướng ngoài miền: ${Sanitizer.sanitizeUrl(request.url)}',
            );
          }
          return NavigationDecision.navigate;
        },
      ),
    );

    await _configurePlatform(webViewController);
    final userAgent = await webViewController.getUserAgent();
    if (userAgent != null) {
      addLog(LogLevel.debug, 'User agent: $userAgent');
    }

    _initialized = true;
    addLog(
      LogLevel.info,
      'Đã khởi tạo trình duyệt với JavaScript, chế độ desktop và cookie giữ phiên.',
    );
  }

  Future<void> reload() async {
    await initialize();
    addLog(LogLevel.info, 'Đã yêu cầu tải lại');
    await controller.reload();
  }

  Future<void> goBackOrClose(VoidCallback close) async {
    await initialize();
    if (await controller.canGoBack()) {
      addLog(LogLevel.info, 'Quay lại trong trình duyệt');
      await controller.goBack();
      return;
    }
    addLog(LogLevel.info, 'Đóng trình duyệt toàn màn hình; vẫn giữ phiên');
    close();
  }

  void addLog(LogLevel level, String message) {
    final next = List<AppLogEntry>.of(logs.value)
      ..insert(
        0,
        AppLogEntry(timestamp: DateTime.now(), level: level, message: message),
      );
    logs.value = next.take(200).toList(growable: false);
  }

  Future<void> _configurePlatform(WebViewController webViewController) async {
    final platform = webViewController.platform;
    if (platform is AndroidWebViewController) {
      await AndroidWebViewController.enableDebugging(false);
      await platform.setUseWideViewPort(true);
      await platform.setTextZoom(100);
      await platform.setMediaPlaybackRequiresUserGesture(false);
      addLog(LogLevel.debug, 'Đã bật viewport rộng cho Android WebView.');
    }
    if (platform is WebKitWebViewController) {
      await platform.setAllowsBackForwardNavigationGestures(true);
      await platform.setAllowsLinkPreview(false);
      await platform.setInspectable(false);
      addLog(LogLevel.debug, 'Đã cấu hình user agent desktop cho WKWebView.');
    }
  }

  void _setCurrentUrl(String url) {
    currentUrl.value = Sanitizer.sanitizeUrl(url);
  }
}
