from __future__ import annotations

from datetime import datetime, timedelta


def format_countdown(now: datetime, target: datetime) -> str:
    remaining = max(timedelta(0), target - now)
    total_seconds = int(remaining.total_seconds())
    hours, rest = divmod(total_seconds, 3600)
    minutes, seconds = divmod(rest, 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
