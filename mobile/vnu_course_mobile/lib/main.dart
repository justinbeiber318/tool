import 'package:flutter/material.dart';

import 'automation/automation_controller.dart';
import 'browser/persistent_webview_controller.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VnuCourseMobilePoc());
}

class VnuCourseMobilePoc extends StatefulWidget {
  const VnuCourseMobilePoc({super.key});

  @override
  State<VnuCourseMobilePoc> createState() => _VnuCourseMobilePocState();
}

class _VnuCourseMobilePocState extends State<VnuCourseMobilePoc> {
  final PersistentWebViewController webView =
      PersistentWebViewController.loginTest();
  late final AutomationController automation =
      AutomationController(webView: webView);

  @override
  void dispose() {
    automation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VNU WebView PoC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      home: HomeScreen(automation: automation),
    );
  }
}
