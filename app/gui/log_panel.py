from __future__ import annotations

import logging

from PySide6.QtCore import QObject, Signal
from PySide6.QtWidgets import QGroupBox, QPlainTextEdit, QVBoxLayout

from app.utils.logger import LOG_FORMAT, MillisecondFormatter, TIME_FORMAT
from app.utils.security import sanitize_text


class LogEmitter(QObject):
    message = Signal(str)


class QtLogHandler(logging.Handler):
    def __init__(self, emitter: LogEmitter) -> None:
        super().__init__()
        self.emitter = emitter
        self.setFormatter(MillisecondFormatter(LOG_FORMAT, TIME_FORMAT))

    def emit(self, record: logging.LogRecord) -> None:
        self.emitter.message.emit(sanitize_text(self.format(record)))


class LogPanel(QGroupBox):
    def __init__(self) -> None:
        super().__init__("Logs")
        self.log_view = QPlainTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setMaximumBlockCount(2000)
        self.emitter = LogEmitter()
        self.emitter.message.connect(self.append_message)
        self.handler = QtLogHandler(self.emitter)
        logging.getLogger().addHandler(self.handler)

        layout = QVBoxLayout(self)
        layout.addWidget(self.log_view)

    def append_message(self, message: str) -> None:
        self.log_view.appendPlainText(message)
