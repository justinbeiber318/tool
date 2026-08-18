from __future__ import annotations

from PySide6.QtWidgets import QFormLayout, QGroupBox, QLabel


class StatusPanel(QGroupBox):
    def __init__(self) -> None:
        super().__init__("Status")
        self.status_label = QLabel("Waiting")
        self.task_label = QLabel("Idle")
        self.countdown_label = QLabel("00:00:00")
        self.clock_label = QLabel("Local")

        layout = QFormLayout(self)
        layout.addRow("Status:", self.status_label)
        layout.addRow("Current task:", self.task_label)
        layout.addRow("Countdown:", self.countdown_label)
        layout.addRow("Clock source:", self.clock_label)

    def set_status(self, status: str) -> None:
        self.status_label.setText(status)

    def set_task(self, task: str) -> None:
        self.task_label.setText(task)

    def set_countdown(self, countdown: str) -> None:
        self.countdown_label.setText(countdown)

    def set_clock_source(self, text: str) -> None:
        self.clock_label.setText(text)
