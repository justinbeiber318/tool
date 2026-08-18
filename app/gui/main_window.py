from __future__ import annotations

import asyncio
import logging
import threading
from datetime import datetime

from PySide6.QtCore import QDate, QThread, QTime, Qt, Signal
from PySide6.QtWidgets import (
    QCheckBox,
    QDateEdit,
    QFileDialog,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QTimeEdit,
    QVBoxLayout,
    QWidget,
)

from app.adapters.university_adapter import UniversityAdapter
from app.adapters.generic import AdapterError
from app.automation.browser import BrowserDiscovery, BrowserError, BrowserManager
from app.automation.local_mock_site import ensure_local_mock_site
from app.automation.login import LoginFlowError, ensure_logged_in
from app.automation.registration import submit_registration
from app.automation.scanner import scan_courses
from app.automation.scheduler import wait_until
from app.automation.state_machine import StateMachine
from app.gui.course_form import CourseForm
from app.gui.log_panel import LogPanel
from app.gui.login_form import LoginForm
from app.gui.status_panel import StatusPanel
from app.models.config import AppConfig, BrowserSettings
from app.models.course import CourseTarget
from app.models.state import AutomationState, ErrorCode, ResultStatus
from app.utils.storage import load_config, save_config


logger = logging.getLogger(__name__)


class AutomationThread(QThread):
    state_changed = Signal(str)
    task_changed = Signal(str)
    countdown_changed = Signal(str)
    fatal_error = Signal(str, str, str)
    finished_cleanly = Signal()

    def __init__(self, config: AppConfig, password: str) -> None:
        super().__init__()
        self.config = config
        self.password = password
        self._stop_requested = threading.Event()

    def request_stop(self) -> None:
        self._stop_requested.set()

    def run(self) -> None:
        try:
            asyncio.run(self._run_async())
        finally:
            self.password = ""
            self.finished_cleanly.emit()

    async def _run_async(self) -> None:
        state_machine = StateMachine()
        browser = BrowserManager(self.config.browser)
        adapter = UniversityAdapter(self.config.site)

        try:
            if ensure_local_mock_site(self.config.site):
                logger.info("Local mock site is ready")

            self._transition(state_machine, AutomationState.STARTING_BROWSER, "Starting browser")
            page = await browser.start()

            self._transition(state_machine, AutomationState.OPENING_LOGIN_PAGE, "Opening login page")
            self._transition(state_machine, AutomationState.LOGGING_IN, "Checking session and logging in")
            login_result = await ensure_logged_in(
                page,
                adapter,
                self.config.username,
                self.password,
                captcha_timeout_seconds=self.config.automation.captcha_timeout_seconds,
                on_captcha_required=lambda: self._transition(
                    state_machine,
                    AutomationState.CAPTCHA_REQUIRED,
                    "CAPTCHA đang yêu cầu xác minh. Vui lòng hoàn thành trong trình duyệt.",
                ),
            )
            logger.info(login_result.message)

            self._transition(state_machine, AutomationState.OPENING_REGISTRATION_PAGE, "Opening registration page")
            await adapter.open_registration_page(page)

            self._transition(state_machine, AutomationState.SCANNING, "Scanning courses")
            courses = await scan_courses(page, adapter)
            logger.info("Detected %s courses on registration page", len(courses))

            self._transition(state_machine, AutomationState.READY, "Ready")
            if self.config.target_time is not None:
                self._transition(state_machine, AutomationState.WAITING_TIME, f"Waiting until {self.config.target_time.time()}")
                cancel_event = asyncio.Event()
                monitor = asyncio.create_task(self._mirror_stop_event(cancel_event))
                wait_result = await wait_until(
                    self.config.target_time,
                    allow_late_execution=self.config.automation.allow_late_execution,
                    on_countdown=lambda seconds: self.countdown_changed.emit(_seconds_to_hhmmss(seconds)),
                    cancel_event=cancel_event,
                )
                monitor.cancel()
                if not wait_result.reached:
                    self._transition(state_machine, AutomationState.STOPPED, "Scheduler stopped before target time")
                    return

            if self._stop_requested.is_set():
                self._transition(state_machine, AutomationState.STOPPED, "Stopped")
            else:
                self._transition(state_machine, AutomationState.SELECTING, "Selecting courses")
                self._transition(state_machine, AutomationState.VERIFYING_SELECTION, "Verifying selected courses")
                self._transition(state_machine, AutomationState.SUBMITTING, "Submitting registration")
                result = await submit_registration(
                    page,
                    adapter,
                    self.config.courses,
                    strict_mode=self.config.automation.strict_mode,
                )
                self._transition(state_machine, AutomationState.WAITING_RESULT, "Waiting for registration result")
                for course_result in result.course_results:
                    logger.info(
                        "%s %s %s %s",
                        course_result.course_code,
                        course_result.class_code or "",
                        course_result.status.value,
                        course_result.message,
                    )
                logger.info("Overall result: %s %s", result.overall_status.value, result.message)
                if result.overall_status == ResultStatus.SUCCESS:
                    self._transition(state_machine, AutomationState.SUCCESS, "Registration successful")
                elif result.overall_status == ResultStatus.PARTIAL_SUCCESS:
                    self._transition(state_machine, AutomationState.PARTIAL_SUCCESS, "Registration partially successful")
                else:
                    self._transition(state_machine, AutomationState.FAILED, "Registration failed")

        except BrowserError as exc:
            logger.exception("Browser error")
            self.state_changed.emit(AutomationState.FAILED.value)
            self.fatal_error.emit(exc.code.value, "Browser error", str(exc))
        except (AdapterError, LoginFlowError) as exc:
            logger.exception("Automation flow error")
            self.state_changed.emit(AutomationState.FAILED.value)
            self.fatal_error.emit(exc.code.value, "Automation flow error", str(exc))
        except Exception as exc:
            logger.exception("Automation failed")
            self.state_changed.emit(AutomationState.FAILED.value)
            self.fatal_error.emit(ErrorCode.RESULT_UNKNOWN.value, "Automation failed", str(exc))
        finally:
            if self.config.browser.close_browser_on_stop:
                await browser.stop()

    async def _mirror_stop_event(self, cancel_event: asyncio.Event) -> None:
        while not self._stop_requested.is_set():
            await asyncio.sleep(0.1)
        cancel_event.set()

    def _transition(self, state_machine: StateMachine, state: AutomationState, task: str) -> None:
        state_machine.transition_to(state)
        logger.info("%s", task)
        self.state_changed.emit(state.value)
        self.task_changed.emit(task)


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Student Registration Tool")
        self.resize(1040, 720)
        self.config = load_config()
        self.worker: AutomationThread | None = None

        self.login_form = LoginForm()
        self.login_form.set_username(self.config.username, self.config.remember_username)

        self.course_form = CourseForm()
        self.course_form.set_courses(self.config.courses)

        self.status_panel = StatusPanel()
        self.log_panel = LogPanel()

        self.date_edit = QDateEdit()
        self.date_edit.setCalendarPopup(True)
        self.date_edit.setDate(QDate.currentDate())
        self.time_edit = QTimeEdit()
        self.time_edit.setDisplayFormat("HH:mm:ss")
        self.time_edit.setTime(QTime.currentTime().addSecs(300))
        if self.config.target_time is not None:
            self.date_edit.setDate(QDate(self.config.target_time.year, self.config.target_time.month, self.config.target_time.day))
            self.time_edit.setTime(QTime(self.config.target_time.hour, self.config.target_time.minute, self.config.target_time.second))

        self.strict_check = QCheckBox("Chỉ submit nếu tất cả môn đều sẵn sàng")
        self.strict_check.setChecked(self.config.automation.strict_mode)
        self.close_browser_check = QCheckBox("Đóng browser khi Stop")
        self.close_browser_check.setChecked(self.config.browser.close_browser_on_stop)
        self.screenshot_check = QCheckBox("Save screenshot on error")
        self.screenshot_check.setChecked(self.config.automation.save_screenshot_on_error)

        self.browser_path_edit = QLineEdit(self.config.browser.executable_path or "")
        self.browser_path_edit.setPlaceholderText("Auto-detect Chrome/Edge")
        self.browser_browse_button = QPushButton("Browse")
        self.browser_browse_button.clicked.connect(self.browse_browser)
        self.detect_browser_label = QLabel(self.detect_browser_text())

        self.start_button = QPushButton("START")
        self.stop_button = QPushButton("STOP")
        self.stop_button.setEnabled(False)
        self.start_button.clicked.connect(self.start_automation)
        self.stop_button.clicked.connect(self.stop_automation)

        self._build_layout()

    def _build_layout(self) -> None:
        time_box = QGroupBox("Registration time")
        time_layout = QFormLayout(time_box)
        time_layout.addRow("Date:", self.date_edit)
        time_layout.addRow("Time:", self.time_edit)

        settings_box = QGroupBox("Settings")
        browser_line = QHBoxLayout()
        browser_line.addWidget(self.browser_path_edit)
        browser_line.addWidget(self.browser_browse_button)
        settings_layout = QFormLayout(settings_box)
        settings_layout.addRow("Browser:", browser_line)
        settings_layout.addRow("Detected:", self.detect_browser_label)
        settings_layout.addRow("", self.strict_check)
        settings_layout.addRow("", self.close_browser_check)
        settings_layout.addRow("", self.screenshot_check)

        control_box = QGroupBox("Control")
        control_layout = QHBoxLayout(control_box)
        control_layout.addWidget(self.start_button)
        control_layout.addWidget(self.stop_button)
        control_layout.addStretch(1)

        left = QVBoxLayout()
        left.addWidget(self.login_form)
        left.addWidget(time_box)
        left.addWidget(settings_box)
        left.addWidget(control_box)
        left.addWidget(self.status_panel)
        left.addStretch(1)

        right = QVBoxLayout()
        right.addWidget(self.course_form, 3)
        right.addWidget(self.log_panel, 2)

        root = QHBoxLayout()
        root.addLayout(left, 1)
        root.addLayout(right, 2)

        container = QWidget()
        container.setLayout(root)
        self.setCentralWidget(container)

    def browse_browser(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Select browser executable", "", "Browser (*.exe)")
        if path:
            self.browser_path_edit.setText(path)
            self.detect_browser_label.setText(self.detect_browser_text(path))

    def detect_browser_text(self, user_path: str | None = None) -> str:
        discovery = BrowserDiscovery()
        candidate = discovery.validate_user_path(user_path) if user_path else discovery.detect()
        if candidate is None:
            return "Không tìm thấy Chrome hoặc Edge."
        return f"{candidate.name}: {candidate.executable_path}"

    def start_automation(self) -> None:
        config = self._collect_config()
        errors = self._validate(config)
        if errors:
            QMessageBox.warning(self, "Invalid input", "\n".join(errors))
            return

        password = self.login_form.password()
        save_config(config)
        self.config = config
        self.login_form.clear_password()
        self.worker = AutomationThread(config, password)
        self.worker.state_changed.connect(self.status_panel.set_status)
        self.worker.task_changed.connect(self.status_panel.set_task)
        self.worker.countdown_changed.connect(self.status_panel.set_countdown)
        self.worker.fatal_error.connect(self.show_fatal_error)
        self.worker.finished_cleanly.connect(self.on_worker_finished)

        self.start_button.setEnabled(False)
        self.stop_button.setEnabled(True)
        self.worker.start()

    def stop_automation(self) -> None:
        if self.worker is not None:
            logger.info("Stop requested")
            self.worker.request_stop()
        self.stop_button.setEnabled(False)

    def on_worker_finished(self) -> None:
        self.start_button.setEnabled(True)
        self.stop_button.setEnabled(False)
        self.worker = None

    def show_fatal_error(self, code: str, summary: str, detail: str) -> None:
        QMessageBox.critical(self, code, f"{summary}\n\n{detail}")

    def closeEvent(self, event: object) -> None:
        if self.worker is not None and self.worker.isRunning():
            result = QMessageBox.question(
                self,
                "Automation đang chạy",
                "Automation đang chạy.\nBạn có chắc muốn thoát?",
            )
            if result != QMessageBox.StandardButton.Yes:
                event.ignore()
                return
            self.worker.request_stop()
            self.worker.wait(3000)
        event.accept()

    def _collect_config(self) -> AppConfig:
        date = self.date_edit.date()
        time_value = self.time_edit.time()
        target = datetime(
            date.year(),
            date.month(),
            date.day(),
            time_value.hour(),
            time_value.minute(),
            time_value.second(),
        )
        config = AppConfig(
            username=self.login_form.username(),
            remember_username=self.login_form.remember_username(),
            target_time=target,
            courses=self.course_form.courses(),
            site=self.config.site,
        )
        config.browser = BrowserSettings(
            executable_path=self.browser_path_edit.text().strip() or None,
            allow_bundled_chromium=False,
            close_browser_on_stop=self.close_browser_check.isChecked(),
            user_data_dir=self.config.browser.user_data_dir,
        )
        config.automation.strict_mode = self.strict_check.isChecked()
        config.automation.save_screenshot_on_error = self.screenshot_check.isChecked()
        return config

    def _validate(self, config: AppConfig) -> list[str]:
        errors: list[str] = []
        if not config.username:
            errors.append("Username is required")
        if not self.login_form.password():
            errors.append("Password is required")
        if config.target_time is None or config.target_time <= datetime.now():
            errors.append("Thời gian đăng ký đã qua. Vui lòng chọn thời gian mới.")
        if not config.courses:
            errors.append("At least one course is required")

        seen: set[tuple[str, str, str]] = set()
        for target in config.courses:
            errors.extend(target.validate())
            key = target.normalized_key()
            if key in seen:
                errors.append(f"Duplicate course: {target.course_code}")
            seen.add(key)
        return errors


def _seconds_to_hhmmss(seconds: float) -> str:
    total_seconds = int(max(0.0, seconds))
    hours, rest = divmod(total_seconds, 3600)
    minutes, seconds_part = divmod(rest, 60)
    return f"{hours:02d}:{minutes:02d}:{seconds_part:02d}"
