from __future__ import annotations

import logging
from datetime import datetime
from pathlib import Path


LOG_FORMAT = "[%(asctime)s.%(msecs)03d] %(levelname)-5s %(message)s"
TIME_FORMAT = "%H:%M:%S"


class MillisecondFormatter(logging.Formatter):
    converter = datetime.fromtimestamp

    def formatTime(self, record: logging.LogRecord, datefmt: str | None = None) -> str:
        created = self.converter(record.created)
        if datefmt:
            return created.strftime(datefmt)
        return created.strftime(TIME_FORMAT)


def configure_logging() -> None:
    log_dir = Path("logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"app-{datetime.now().date().isoformat()}.log"

    root = logging.getLogger()
    root.setLevel(logging.INFO)
    root.handlers.clear()

    formatter = MillisecondFormatter(LOG_FORMAT, TIME_FORMAT)

    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(formatter)
    root.addHandler(file_handler)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    root.addHandler(console_handler)
