import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../browser/desktop_mode.dart';

enum VnuRegistrationStatus {
  clicked,
  notFound,
  ambiguous,
  actionNotFound,
  wrongPage,
}

class VnuRegistrationResult {
  const VnuRegistrationResult({
    required this.status,
    required this.message,
    this.rowText = '',
  });

  final VnuRegistrationStatus status;
  final String message;
  final String rowText;
}

class VnuRegistrationAdapter {
  Future<VnuRegistrationResult> registerCourse(
    WebViewController controller, {
    required String classCode,
  }) async {
    await _assertAllowedHost(controller);
    final result = await controller.runJavaScriptReturningResult('''
(() => {
  const normalize = (value) => String(value || '')
    .replace(/[\\u0110\\u0111]/g, 'd')
    .normalize('NFD')
    .replace(/[\\u0300-\\u036f]/g, '')
    .toLowerCase()
    .replace(/\\s+/g, ' ')
    .trim();
  const rawText = (element) => [
    element.innerText,
    element.value,
    element.title,
    element.getAttribute && element.getAttribute('aria-label'),
  ].filter(Boolean).join(' ');
  const visible = (element) => {
    const style = window.getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return style.display !== 'none' &&
      style.visibility !== 'hidden' &&
      rect.width >= 0 &&
      rect.height >= 0;
  };
  const clickTarget = (row) => {
    const candidates = Array.from(
      row.querySelectorAll('button,a,input,[onclick],[role="button"]')
    ).filter(visible);
    for (const candidate of candidates) {
      const text = normalize(rawText(candidate));
      if (text.includes('dang')) {
        return candidate;
      }
    }
    for (const cell of Array.from(row.cells || [])) {
      const text = normalize(rawText(cell));
      if (text === 'dang') {
        return cell.querySelector('button,a,input,[onclick],[role="button"]') ||
          cell;
      }
    }
    return null;
  };
  const containsToken = (row, target) => {
    if (!target) return true;
    const normalizedTarget = normalize(target);
    return Array.from(row.cells || []).some((cell) => {
      const pieces = normalize(cell.innerText).split(/[^a-z0-9_.-]+/);
      return pieces.includes(normalizedTarget);
    }) || normalize(row.innerText).includes(normalizedTarget);
  };
  const containsClassCode = (row, target) => {
    const normalizedTarget = normalize(target);
    const compactTarget = normalizedTarget.replace(/[^a-z0-9_.-]+/g, '');
    return Array.from(row.cells || []).some((cell) => {
      const normalizedCell = normalize(cell.innerText);
      const compactCell = normalizedCell.replace(/[^a-z0-9_.-]+/g, '');
      return compactCell === compactTarget ||
        compactCell.includes(compactTarget) ||
        normalizedCell.split(/[^a-z0-9_.-]+/).includes(normalizedTarget);
    });
  };

  const url = window.location.href;
  if (!url.includes('/dang-ky-mon-hoc')) {
    return JSON.stringify({
      status: 'wrongPage',
      message: 'Hãy mở trang đăng ký môn học trước.',
    });
  }

  const classCode = ${jsonEncode(classCode)};
  const rows = Array.from(document.querySelectorAll('tr'));
  const matches = rows.filter((row) => containsClassCode(row, classCode));

  if (matches.length === 0) {
    return JSON.stringify({
      status: 'notFound',
      message: 'Không tìm thấy dòng mã lớp này.',
    });
  }
  if (matches.length > 1) {
    return JSON.stringify({
      status: 'ambiguous',
      message: `Tìm thấy \${matches.length} dòng; hãy nhập đầy đủ mã lớp.`,
      rowText: matches.slice(0, 3).map((row) => row.innerText.trim()).join('\\n---\\n'),
    });
  }

  const row = matches[0];
  const target = clickTarget(row);
  if (!target) {
    return JSON.stringify({
      status: 'actionNotFound',
      message: 'Đã tìm thấy dòng, nhưng không thấy nút Đăng.',
      rowText: row.innerText.trim(),
    });
  }
  row.scrollIntoView({ block: 'center', inline: 'center' });
  target.click();
  return JSON.stringify({
    status: 'clicked',
    message: 'Đã bấm Đăng cho dòng lớp phù hợp.',
    rowText: row.innerText.trim(),
  });
})();
''');
    return _parseResult(result);
  }

  Future<void> _assertAllowedHost(WebViewController controller) async {
    final url = await controller.currentUrl();
    if (url == null || !DesktopMode.isAllowedTopLevelUrl(url)) {
      throw StateError('Tự động hóa tạm dừng: trang hiện tại không hợp lệ.');
    }
  }

  VnuRegistrationResult _parseResult(Object value) {
    final raw = value.toString();
    final normalized = raw.length >= 2 && raw.startsWith('"')
        ? jsonDecode(raw) as String
        : raw;
    final decoded = jsonDecode(normalized) as Map<String, dynamic>;
    final statusName = decoded['status'] as String? ?? 'actionNotFound';
    final status = VnuRegistrationStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => VnuRegistrationStatus.actionNotFound,
    );
    return VnuRegistrationResult(
      status: status,
      message: decoded['message'] as String? ?? '',
      rowText: decoded['rowText'] as String? ?? '',
    );
  }
}
