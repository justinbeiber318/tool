import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../browser/persistent_webview_controller.dart';
import '../utils/app_log.dart';

class VerificationWebViewScreen extends StatelessWidget {
  const VerificationWebViewScreen({required this.webView, super.key});

  final PersistentWebViewController webView;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await webView.goBackOrClose(() => Navigator.of(context).pop());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: ValueListenableBuilder<String>(
            valueListenable: webView.currentUrl,
            builder: (context, value, _) => Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await webView.goBackOrClose(() => Navigator.of(context).pop());
            },
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
              onPressed: webView.reload,
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () {
                webView.addLog(
                  LogLevel.info,
                  'Fullscreen WebView closed by user; session retained.',
                );
                Navigator.of(context).pop();
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: ValueListenableBuilder<int>(
              valueListenable: webView.progress,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value <= 0 || value >= 100 ? null : value / 100,
                  minHeight: 4,
                );
              },
            ),
          ),
        ),
        body: WebViewWidget(controller: webView.controller),
      ),
    );
  }
}
