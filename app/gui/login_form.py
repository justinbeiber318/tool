from __future__ import annotations

from PySide6.QtWidgets import QCheckBox, QFormLayout, QGroupBox, QLineEdit


class LoginForm(QGroupBox):
    def __init__(self) -> None:
        super().__init__("Account")
        self.username_edit = QLineEdit()
        self.username_edit.setPlaceholderText("Username")

        self.password_edit = QLineEdit()
        self.password_edit.setPlaceholderText("Password")
        self.password_edit.setEchoMode(QLineEdit.EchoMode.Password)

        self.remember_username_check = QCheckBox("Remember username")

        layout = QFormLayout(self)
        layout.addRow("Username:", self.username_edit)
        layout.addRow("Password:", self.password_edit)
        layout.addRow("", self.remember_username_check)

    def username(self) -> str:
        return self.username_edit.text().strip()

    def password(self) -> str:
        return self.password_edit.text()

    def remember_username(self) -> bool:
        return self.remember_username_check.isChecked()

    def set_username(self, username: str, remember: bool) -> None:
        self.username_edit.setText(username)
        self.remember_username_check.setChecked(remember)

    def clear_password(self) -> None:
        self.password_edit.clear()
