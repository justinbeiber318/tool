import 'package:flutter/material.dart';

import '../automation/automation_controller.dart';
import '../models/automation_state.dart';
import '../models/session_info.dart';
import '../services/secure_storage_service.dart';
import '../utils/app_log.dart';
import 'verification_webview_screen.dart';

const Color _ink = Color(0xFF10201D);
const Color _muted = Color(0xFF64736F);
const Color _line = Color(0xFFD7E2DE);
const Color _green = Color(0xFF10805E);
const Color _amber = Color(0xFFC98617);
const Color _red = Color(0xFFB42318);
const Color _blue = Color(0xFF246BFE);

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
  final TextEditingController classCode = TextEditingController();

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
    classCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webView = automation.webView;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Đăng ký học VNU'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: webView.reload,
          ),
          IconButton(
            tooltip: 'Dừng',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: automation.stop,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            _StatusBanner(controller: automation),
            const SizedBox(height: 12),
            _ActionPanel(
              controller: automation,
              username: username,
              password: password,
              saveAccount: _saveAccount,
            ),
            const SizedBox(height: 12),
            _CoursePanel(controller: automation, classCode: classCode),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            _SessionPanel(controller: automation),
            const SizedBox(height: 12),
            _WebViewPanel(controller: automation),
            const SizedBox(height: 12),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.controller});

  final AutomationController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: ValueListenableBuilder<AutomationState>(
        valueListenable: controller.state,
        builder: (context, state, _) {
          final tone = _toneForState(state);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tone.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(tone.icon, color: tone.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tone.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<String>(
                      valueListenable: controller.task,
                      builder: (context, value, _) => Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: _muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StateChip(label: state.label, color: tone.color),
            ],
          );
        },
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
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PanelTitle(icon: Icons.route, title: 'Thao tác'),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Mở đăng nhập'),
            onPressed: () async {
              await saveAccount();
              await controller.openLoginTest();
              if (!context.mounted) {
                return;
              }
              await _openWebView(context, controller);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.password),
                  label: const Text('Tự điền'),
                  onPressed: () async {
                    await saveAccount();
                    await controller.fillCredentials(
                      username: username.text,
                      password: password.text,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    await _openWebView(context, controller);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Kiểm tra'),
                  onPressed: controller.checkLoginStatus,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Mở trình duyệt',
                icon: const Icon(Icons.open_in_full),
                onPressed: () async {
                  await controller.webView.initialize();
                  if (!context.mounted) {
                    return;
                  }
                  await _openWebView(context, controller);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoursePanel extends StatelessWidget {
  const _CoursePanel({required this.controller, required this.classCode});

  final AutomationController controller;
  final TextEditingController classCode;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PanelTitle(icon: Icons.fact_check_outlined, title: 'Môn học'),
          const SizedBox(height: 12),
          TextField(
            controller: classCode,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Mã lớp môn học',
              hintText: 'PHI100212',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Đăng ký môn'),
            onPressed: () async {
              final classText = classCode.text.trim();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Xác nhận đăng ký?'),
                  content: Text('Bấm Đăng cho lớp $classText?'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Đăng ký'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) {
                return;
              }
              await controller.registerCourse(classCode: classCode.text);
              if (!context.mounted) {
                return;
              }
              await _openWebView(context, controller);
            },
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
          const _PanelTitle(
            icon: Icons.account_circle_outlined,
            title: 'Tài khoản',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: username,
            enabled: !loading,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Tên truy cập',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            enabled: !loading,
            obscureText: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: rememberUsername,
            onChanged: loading ? null : onRememberUsernameChanged,
            title: const Text('Nhớ tên truy cập'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: rememberPassword,
            onChanged: loading ? null : onRememberPasswordChanged,
            title: const Text('Nhớ mật khẩu'),
          ),
        ],
      ),
    );
  }
}

Future<void> _openWebView(
  BuildContext context,
  AutomationController controller,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VerificationWebViewScreen(webView: controller.webView),
      fullscreenDialog: true,
    ),
  );
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
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PanelTitle(icon: Icons.schedule_outlined, title: 'Phiên'),
                SizedBox(height: 12),
                _MetricLine(label: 'Trạng thái', value: 'Chưa xác nhận'),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _PanelTitle(icon: Icons.schedule_outlined, title: 'Phiên'),
              const SizedBox(height: 12),
              _MetricLine(
                label: 'Đăng nhập lúc',
                value: _formatTime(session.loginTime),
              ),
              _MetricLine(
                label: 'Hết hạn lúc',
                value: _formatTime(session.expiresAt),
              ),
              ValueListenableBuilder<Duration>(
                valueListenable: controller.sessionService.remaining,
                builder: (context, value, _) => _MetricLine(
                  label: 'Còn lại',
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

class _WebViewPanel extends StatelessWidget {
  const _WebViewPanel({required this.controller});

  final AutomationController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PanelTitle(icon: Icons.public, title: 'Trình duyệt'),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: controller.webView.currentUrl,
            builder: (context, value, _) => SelectableText(
              value,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _muted,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: controller.webView.progress,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value <= 0 || value >= 100 ? null : value / 100,
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
            ),
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
        color: const Color(0xFF17211F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.terminal, color: Color(0xFFB7F4D3), size: 18),
                SizedBox(width: 8),
                Text(
                  'Nhật ký',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<AppLogEntry>>(
              valueListenable: controller.webView.logs,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  return const Text(
                    'Chưa có sự kiện.',
                    style: TextStyle(color: Color(0xFFB8C7C2)),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Text(
                        entry.formatted,
                        style: const TextStyle(
                          color: Color(0xFFE8F2EF),
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.35,
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
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: _green),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _muted),
            ),
          ),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _ink,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateTone {
  const _StateTone({
    required this.title,
    required this.color,
    required this.icon,
  });

  final String title;
  final Color color;
  final IconData icon;
}

_StateTone _toneForState(AutomationState state) {
  switch (state) {
    case AutomationState.loginSuccess:
    case AutomationState.courseRegistered:
      return const _StateTone(
        title: 'Sẵn sàng',
        color: _green,
        icon: Icons.check_circle,
      );
    case AutomationState.captchaRequired:
    case AutomationState.waitingLogin:
    case AutomationState.openingLoginPage:
    case AutomationState.fillingCredentials:
    case AutomationState.checkingSession:
    case AutomationState.registeringCourse:
      return const _StateTone(
        title: 'Đang chạy',
        color: _amber,
        icon: Icons.hourglass_top,
      );
    case AutomationState.failed:
    case AutomationState.sessionExpired:
      return const _StateTone(
        title: 'Cần kiểm tra',
        color: _red,
        icon: Icons.error,
      );
    case AutomationState.idle:
    case AutomationState.stopped:
      return const _StateTone(
        title: 'Chờ lệnh',
        color: _blue,
        icon: Icons.radio_button_checked,
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
