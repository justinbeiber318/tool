from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView,
    QDialog,
    QDialogButtonBox,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QTextEdit,
    QVBoxLayout,
)

from app.models.course import CourseTarget, parse_course_lines


class ImportDialog(QDialog):
    def __init__(self, parent: object | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Import courses")
        self.text_edit = QTextEdit()
        self.text_edit.setPlaceholderText("INT1234 123456 01 1\nINT2345 123457 01 2")
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)

        layout = QVBoxLayout(self)
        layout.addWidget(self.text_edit)
        layout.addWidget(buttons)

    def text(self) -> str:
        return self.text_edit.toPlainText()


class CourseForm(QGroupBox):
    HEADERS = ("Course Code", "Class Code", "Group", "Priority")

    def __init__(self) -> None:
        super().__init__("Courses")
        self.table = QTableWidget(0, len(self.HEADERS))
        self.table.setHorizontalHeaderLabels(self.HEADERS)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.DoubleClicked | QAbstractItemView.EditTrigger.EditKeyPressed)
        self.table.setAlternatingRowColors(True)

        self.add_button = QPushButton("Add")
        self.remove_button = QPushButton("Remove")
        self.import_button = QPushButton("Import text")
        self.paste_button = QPushButton("Paste rows")

        self.add_button.clicked.connect(self.add_empty_row)
        self.remove_button.clicked.connect(self.remove_selected_rows)
        self.import_button.clicked.connect(self.import_from_text)
        self.paste_button.clicked.connect(self.paste_rows)

        toolbar = QHBoxLayout()
        toolbar.addWidget(self.add_button)
        toolbar.addWidget(self.remove_button)
        toolbar.addWidget(self.import_button)
        toolbar.addWidget(self.paste_button)
        toolbar.addStretch(1)

        layout = QVBoxLayout(self)
        layout.addLayout(toolbar)
        layout.addWidget(self.table)

    def add_empty_row(self) -> None:
        self.add_course(CourseTarget(course_code="", priority=self.table.rowCount() + 1))

    def add_course(self, target: CourseTarget) -> None:
        row = self.table.rowCount()
        self.table.insertRow(row)
        values = [
            target.course_code,
            target.class_code or "",
            target.group_code or "",
            str(target.priority),
        ]
        for column, value in enumerate(values):
            item = QTableWidgetItem(value)
            if column == 3:
                item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(row, column, item)

    def set_courses(self, targets: list[CourseTarget]) -> None:
        self.table.setRowCount(0)
        for target in targets:
            self.add_course(target)

    def remove_selected_rows(self) -> None:
        rows = sorted({index.row() for index in self.table.selectedIndexes()}, reverse=True)
        for row in rows:
            self.table.removeRow(row)

    def import_from_text(self) -> None:
        dialog = ImportDialog(self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            self.add_targets(parse_course_lines(dialog.text()))

    def paste_rows(self) -> None:
        clipboard = self.window().clipboard() if hasattr(self.window(), "clipboard") else None
        if clipboard is None:
            from PySide6.QtWidgets import QApplication

            clipboard = QApplication.clipboard()
        self.add_targets(parse_course_lines(clipboard.text()))

    def add_targets(self, targets: list[CourseTarget]) -> None:
        for target in targets:
            self.add_course(target)

    def courses(self) -> list[CourseTarget]:
        targets: list[CourseTarget] = []
        for row in range(self.table.rowCount()):
            course_code = self._cell(row, 0)
            class_code = self._cell(row, 1) or None
            group_code = self._cell(row, 2) or None
            priority_raw = self._cell(row, 3)
            priority = int(priority_raw) if priority_raw.isdigit() else row + 1
            if course_code or class_code or group_code:
                targets.append(
                    CourseTarget(
                        course_code=course_code,
                        class_code=class_code,
                        group_code=group_code,
                        priority=priority,
                    )
                )
        return targets

    def _cell(self, row: int, column: int) -> str:
        item = self.table.item(row, column)
        return item.text().strip() if item is not None else ""
