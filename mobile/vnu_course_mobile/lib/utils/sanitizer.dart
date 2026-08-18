class Sanitizer {
  static final RegExp _sensitiveField = RegExp(
    r'(password|passwd|pwd|token|cookie|secret|authorization)',
    caseSensitive: false,
  );

  static String sanitizeText(String text) {
    return text
        .split('\n')
        .map((line) => _sensitiveField.hasMatch(line) ? '[redacted]' : line)
        .join('\n');
  }

  static String sanitizeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.queryParameters.isEmpty) {
      return sanitizeText(url);
    }

    final sanitizedQuery = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      sanitizedQuery[entry.key] =
          _sensitiveField.hasMatch(entry.key) ? '[redacted]' : entry.value;
    }
    return uri.replace(queryParameters: sanitizedQuery).toString();
  }

  static String maskUsername(String username) {
    final clean = username.trim();
    if (clean.isEmpty) {
      return '';
    }
    if (clean.length <= 2) {
      return '*' * clean.length;
    }
    return '${clean[0]}***${clean[clean.length - 1]}';
  }
}
