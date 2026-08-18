from __future__ import annotations

import re


SENSITIVE_FIELD_RE = re.compile(
    r"(password|passwd|pwd|token|cookie|secret|authorization)",
    re.IGNORECASE,
)


def mask_username(username: str) -> str:
    clean = username.strip()
    if not clean:
        return ""
    if len(clean) <= 2:
        return "*" * len(clean)
    return f"{clean[0]}***{clean[-1]}"


def sanitize_text(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines():
        if SENSITIVE_FIELD_RE.search(line):
            lines.append("[redacted]")
        else:
            lines.append(line)
    return "\n".join(lines)
