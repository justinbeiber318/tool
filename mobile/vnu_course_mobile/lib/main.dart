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
  late final AutomationController automation = AutomationController(
    webView: webView,
  );

  @override
  void dispose() {
    automation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đăng ký học VNU',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F7F5),
          foregroundColor: Color(0xFF10201D),
          elevation: 0,
          centerTitle: false,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD7E2DE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF10805E), width: 1.4),
          ),
        ),
      ),
      home: HomeScreen(automation: automation),
    );
  }
}
