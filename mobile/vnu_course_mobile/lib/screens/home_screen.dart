import 'package:flutter/material.dart';

import '../automation/automation_controller.dart';
import '../models/automation_state.dart';
import '../models/session_info.dart';
import '../services/secure_storage_service.dart';
import '../utils/app_log.dart';
import 'verification_webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.automation, super.key});

  final AutomationController automation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SecureStorageService storage = SecureStorageService();
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool rememberUsername = false;
  bool rememberPassword = false;
  bool loadingAccount = true;

  AutomationController get automation => widget.automation;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webView = automation.webView;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VNU Mobile Automation'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload WebView',
            icon: const Icon(Icons.refresh),
            onPressed: webView.reload,
          ),
          IconButton(
            tooltip: 'Stop',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: automation.stop,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _AutomationStatus(controller: automation),
            const SizedBox(height: 16),
            _AccountPanel(
              loading: loadingAccount,
              username: username,
              password: password,
              rememberUsername: rememberUsername,
              rememberPassword: rememberPassword,
              onRememberUsernameChanged: (value) {
                setState(() => rememberUsername = value);
              },
              onRememberPasswordChanged: (value) {
                setState(() => rememberPassword = value);
              },
            ),
            const SizedBox(height: 16),
            _ActionPanel(
              controller: automation,
              username: username,
              password: password,
              saveAccount: _saveAccount,
            ),
            const SizedBox(height: 16),
            _SessionPanel(controller: automation),
            const SizedBox(height: 16),
            _DebugPanel(controller: automation),
            const SizedBox(height: 16),
            _LogPanel(controller: automation),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAccount() async {
    final settings = await storage.loadAccountSettings();
    final savedPassword = await storage.loadPasswordIfRemembered();
    if (!mounted) {
      return;
    }
    setState(() {
      username.text = settings.username;
      password.text = savedPassword;
      rememberUsername = settings.rememberUsername;
      rememberPassword = settings.rememberPassword;
      loadingAccount = false;
    });
  }

  Future<void> _saveAccount() {
    return storage.saveAccount(
      username: username.text.trim(),
      password: password.text,
      rememberUsername: rememberUsername,
      rememberPassword: rememberPassword,
    );
  }
}

class _AutomationStatus extends StatelessWidget {
  const _AutomationStatus({required this.controller});

  final AutomationController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Status', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ValueListenableBuilder<AutomationState>(
            valueListenable: controller.state,
            builder: (context, value, _) => _DebugLine(
              label: 'State',
              value: value.label,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: controller.task,
            builder: (context, value, _) => _DebugLine(
              label: 'Task',
              value: value,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.loading,
    required this.username,
    required this.password,
    required this.rememberUsername,
    required this.rememberPassword,
    required this.onRememberUsernameChanged,
    required this.onRememberPasswordChanged,
  });

  final bool loading;
  final TextEditingController username;
  final TextEditingController password;
  final bool rememberUsername;
  final bool rememberPassword;
  final ValueChanged<bool> onRememberUsernameChanged;
  final ValueChanged<bool> onRememberPasswordChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: username,
            enabled: !loading,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Username',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            enabled: !loading,
            obscureText: true,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: rememberUsername,
            onChanged: loading
                ? null
                : (value) => onRememberUsernameChanged(value ?? false),
            title: const Text('Remember username'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: rememberPassword,
            onChanged: loading
                ? null
                : (value) => onRememberPasswordChanged(value ?? false),
            title: const Text('Remember password in secure storage'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.controller,
    required this.username,
    required this.password,
    required this.saveAccount,
  });

  final AutomationController controller;
  final TextEditingController username;
  final TextEditingController password;
  final Future<void> Function() saveAccount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        FilledButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Open Login Test'),
          onPressed: () async {
            await saveAccount();
            await controller.openLoginTest();
            if (!context.mounted) {
              return;
            }
            await _openWebView(context);
          },
        ),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.edit),
          label: const Text('Autofill'),
          onPressed: () async {
            await saveAccount();
            await controller.fillCredentials(
              username: username.text,
              password: password.text,
            );
            if (!context.mounted) {
              return;
            }
            await _openWebView(context);
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Check Login'),
          onPressed: controller.checkLoginStatus,
        ),
        IconButton.filledTonal(
          tooltip: 'Open WebView',
          icon: const Icon(Icons.open_in_full),
          onPressed: () async {
            await controller.webView.initialize();
            if (!context.mounted) {
              return;
            }
            await _openWebView(context);
          },
        ),
      ],
    );
  }

  Future<void> _openWebView(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerificationWebViewScreen(
          webView: controller.webView,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({required this.controller});

  final AutomationController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ValueListenableBuilder<SessionInfo?>(
        valueListenable: controller.sessionService.session,
        builder: (context, session, _) {
          if (session == null) {
            return const _DebugLine(
              label: 'Session',
              value: 'Not confirmed',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Session', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _DebugLine(
                label: 'Logged in at',
                value: _formatTime(session.loginTime),
              ),
              const SizedBox(height: 8),
              _DebugLine(
                label: 'Expires at',
                value: _formatTime(session.expiresAt),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<Duration>(
                valueListenable: controller.sessionService.remaining,
                builder: (context, value, _) => _DebugLine(
                  label: 'Remaining',
                  value: _formatDuration(value),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.controller});

  final AutomationController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('WebView', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: controller.webView.currentUrl,
            builder: (context, value, _) => _DebugLine(
              label: 'Current URL',
              value: value,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: controller.webView.progress,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value <= 0 || value >= 100 ? null : value / 100,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'CAPTCHA must be verified manually in this same WebView session.',
          ),
        ],
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.controller});

  final AutomationController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Sanitized Logs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<AppLogEntry>>(
              valueListenable: controller.webView.logs,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  return const Text(
                    'No events yet.',
                    style: TextStyle(color: Color(0xFFCBD5E1)),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Text(
                        entry.formatted,
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _DebugLine extends StatelessWidget {
  const _DebugLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
        ),
      ],
    );
  }
}

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration value) {
  final totalSeconds = value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
