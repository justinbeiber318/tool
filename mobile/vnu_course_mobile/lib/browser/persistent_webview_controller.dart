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

  final ValueNotifier<String> currentUrl = ValueNotifier<String>('not loaded');
  final ValueNotifier<int> progress = ValueNotifier<int>(0);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<List<AppLogEntry>> logs =
      ValueNotifier<List<AppLogEntry>>(<AppLogEntry>[]);

  WebViewController? _controller;
  bool _initialized = false;

  WebViewController get controller {
    final active = _controller;
    if (active == null) {
      throw StateError('WebView has not been initialized.');
    }
    return active;
  }

  Future<void> openLoginTest() async {
    await initialize();
    addLog(LogLevel.info, 'Opening login test: ${loginUrl.host}');
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

    final webViewController =
        WebViewController.fromPlatformCreationParams(params);
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
          addLog(LogLevel.info, 'Started ${Sanitizer.sanitizeUrl(url)}');
        },
        onPageFinished: (url) {
          isLoading.value = false;
          progress.value = 100;
          _setCurrentUrl(url);
          addLog(LogLevel.info, 'Finished ${Sanitizer.sanitizeUrl(url)}');
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
            'Web resource error ${error.errorCode}: ${error.description}',
          );
        },
        onNavigationRequest: (request) {
          if (!DesktopMode.isAllowedTopLevelUrl(request.url)) {
            addLog(
              LogLevel.warning,
              'Off-domain navigation observed: ${Sanitizer.sanitizeUrl(request.url)}',
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
      'WebView initialized with JavaScript, desktop mode, and persistent cookies.',
    );
  }

  Future<void> reload() async {
    await initialize();
    addLog(LogLevel.info, 'Reload requested');
    await controller.reload();
  }

  Future<void> goBackOrClose(VoidCallback close) async {
    await initialize();
    if (await controller.canGoBack()) {
      addLog(LogLevel.info, 'Navigating back inside WebView');
      await controller.goBack();
      return;
    }
    addLog(LogLevel.info, 'Closing fullscreen WebView; controller retained');
    close();
  }

  void addLog(LogLevel level, String message) {
    final next = List<AppLogEntry>.of(logs.value)
      ..insert(
        0,
        AppLogEntry(
          timestamp: DateTime.now(),
          level: level,
          message: message,
        ),
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
      addLog(LogLevel.debug, 'Android WebView wide viewport enabled.');
    }
    if (platform is WebKitWebViewController) {
      await platform.setAllowsBackForwardNavigationGestures(true);
      await platform.setAllowsLinkPreview(false);
      await platform.setInspectable(false);
      addLog(LogLevel.debug, 'WKWebView desktop user agent configured.');
    }
  }

  void _setCurrentUrl(String url) {
    currentUrl.value = Sanitizer.sanitizeUrl(url);
  }
}
