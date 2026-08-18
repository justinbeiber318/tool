from __future__ import annotations

import asyncio
from dataclasses import dataclass

from app.adapters.base import SiteAdapter
from app.automation.captcha import CaptchaDetector
from app.automation.result_parser import build_single_result
from app.models.course import Course, CourseTarget
from app.models.result import RegistrationResult
from app.models.state import ErrorCode
from app.utils.selectors import SUBMIT_TEXTS

try:
    from playwright.async_api import Error as PlaywrightError
    from playwright.async_api import TimeoutError as PlaywrightTimeoutError
except ImportError:  # pragma: no cover - exercised only before dependencies are installed.
    PlaywrightError = RuntimeError
    PlaywrightTimeoutError = TimeoutError


class AdapterError(RuntimeError):
    def __init__(self, code: ErrorCode, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(slots=True)
class GenericSelectors:
    username: str = "#username"
    password: str = "#password"
    login_button: str = "button[type='submit']"
    login_error: str = ".error, [role='alert'], [data-testid='login-error']"
    logged_in_marker: str = "[data-testid='logged-in']"
    registration_marker: str = "[data-testid='registration-page']"
    course_row: str = "[data-course-row]"
    result: str = "[data-testid='result']"


class GenericSiteAdapter(SiteAdapter):
    def __init__(
        self,
        login_url: str,
        registration_url: str,
        *,
        registration_mode: str = "BATCH",
        selectors: GenericSelectors | None = None,
    ) -> None:
        self.login_url = login_url
        self.registration_url = registration_url
        self.registration_mode = registration_mode
        self.selectors = selectors or GenericSelectors()
        self.captcha_detector = CaptchaDetector()

    async def open_login_page(self, page: object) -> None:
        await self._goto(page, self.login_url, ErrorCode.LOGIN_PAGE_FAILED)

    async def is_logged_in(self, page: object) -> bool:
        marker = page.locator(self.selectors.logged_in_marker)
        return await marker.count() > 0

    async def login(self, page: object, username: str, password: str) -> None:
        user_field = page.locator(self.selectors.username)
        pass_field = page.locator(self.selectors.password)
        login_button = page.locator(self.selectors.login_button)

        try:
            await user_field.wait_for(state="visible", timeout=10_000)
        except PlaywrightTimeoutError as exc:
            raise AdapterError(ErrorCode.LOGIN_PAGE_FAILED, "Username field did not appear") from exc

        try:
            await pass_field.wait_for(state="visible", timeout=10_000)
        except PlaywrightTimeoutError as exc:
            raise AdapterError(ErrorCode.LOGIN_PAGE_FAILED, "Password field did not appear") from exc

        if not await login_button.is_enabled():
            raise AdapterError(ErrorCode.LOGIN_FAILED, "Login button is disabled")

        await user_field.fill(username)
        await pass_field.fill(password)
        await login_button.click()
        await self._wait_for_login_outcome(page)

    async def detect_captcha(self, page: object) -> bool:
        return await self.captcha_detector.detect(page)

    async def open_registration_page(self, page: object) -> None:
        await self._goto(page, self.registration_url, ErrorCode.REGISTRATION_PAGE_FAILED)

    async def is_registration_page(self, page: object) -> bool:
        return await page.locator(self.selectors.registration_marker).count() > 0

    async def get_registration_frame(self, page: object) -> object:
        return page

    async def scan_courses(self, page: object) -> list[Course]:
        frame = await self.get_registration_frame(page)
        rows = frame.locator(self.selectors.course_row)
        count = await rows.count()
        courses: list[Course] = []
        for index in range(count):
            row = rows.nth(index)
            courses.append(
                Course(
                    course_code=await row.get_attribute("data-course-code"),
                    class_code=await row.get_attribute("data-class-code"),
                    group_code=await row.get_attribute("data-group-code"),
                    available_slots=_parse_int(await row.get_attribute("data-available-slots")),
                    raw_text=(await row.inner_text()).strip(),
                )
            )
        return courses

    async def select_course(self, page: object, target: CourseTarget) -> None:
        frame = await self.get_registration_frame(page)
        rows = await self._matching_rows(frame, target)
        if not rows:
            raise AdapterError(ErrorCode.COURSE_NOT_FOUND, f"Course not found: {target.course_code}")
        if len(rows) > 1:
            raise AdapterError(ErrorCode.COURSE_AMBIGUOUS, f"Found {len(rows)} rows matching {target.course_code}.")

        row = rows[0]
        if await row.get_attribute("aria-disabled") == "true":
            raise AdapterError(ErrorCode.COURSE_DISABLED, f"Course disabled: {target.course_code}")
        if (await row.get_attribute("data-full")) == "true":
            raise AdapterError(ErrorCode.COURSE_FULL, f"Course full: {target.course_code}")

        checkbox = row.locator("input[type='checkbox'], [role='checkbox']").first
        await checkbox.wait_for(state="visible", timeout=5_000)
        if not await checkbox.is_enabled():
            raise AdapterError(ErrorCode.COURSE_DISABLED, f"Course disabled: {target.course_code}")

        if not await self._is_control_selected(checkbox):
            if hasattr(checkbox, "check"):
                try:
                    await checkbox.check()
                except PlaywrightError:
                    await checkbox.click()
            else:
                await checkbox.click()

        rows_after_action = await self._matching_rows(frame, target)
        if len(rows_after_action) != 1:
            raise AdapterError(ErrorCode.COURSE_AMBIGUOUS, f"Could not verify selected row for {target.course_code}")
        fresh_checkbox = rows_after_action[0].locator("input[type='checkbox'], [role='checkbox']").first
        if not await self._is_control_selected(fresh_checkbox):
            raise AdapterError(ErrorCode.SUBMIT_FAILED, f"Could not verify checkbox selection for {target.course_code}")

    async def submit(self, page: object) -> None:
        frame = await self.get_registration_frame(page)
        candidates = []
        for text in SUBMIT_TEXTS:
            locator = frame.get_by_role("button", name=text, exact=True)
            if await locator.count() > 0:
                candidates.append(locator.first)
        if not candidates:
            raise AdapterError(ErrorCode.SUBMIT_NOT_FOUND, "Submit button not found")
        if len(candidates) > 1:
            raise AdapterError(ErrorCode.SUBMIT_AMBIGUOUS, "Submit button is ambiguous")
        dialog_tasks: list[asyncio.Task[None]] = []

        def on_dialog(dialog: object) -> None:
            dialog_tasks.append(asyncio.create_task(self._handle_registration_dialog(dialog)))

        page.once("dialog", on_dialog)
        try:
            await candidates[0].click()
            try:
                await page.wait_for_load_state("domcontentloaded", timeout=10_000)
            except PlaywrightTimeoutError:
                pass
            if dialog_tasks:
                await asyncio.gather(*dialog_tasks)
        except PlaywrightError as exc:
            raise AdapterError(ErrorCode.SUBMIT_FAILED, str(exc)) from exc

    async def parse_result(self, page: object) -> RegistrationResult:
        result = page.locator(self.selectors.result)
        if await result.count() == 0:
            text = await page.locator("body").inner_text()
        else:
            text = await result.first.inner_text()
        return build_single_result("UNKNOWN", None, text)

    async def _matching_rows(self, frame: object, target: CourseTarget) -> list[object]:
        rows = frame.locator(self.selectors.course_row)
        count = await rows.count()
        matches: list[object] = []
        target_course = target.course_code.strip().casefold()
        target_class = (target.class_code or "").strip().casefold()
        target_group = (target.group_code or "").strip().casefold()

        for index in range(count):
            row = rows.nth(index)
            course_code = ((await row.get_attribute("data-course-code")) or "").strip().casefold()
            class_code = ((await row.get_attribute("data-class-code")) or "").strip().casefold()
            group_code = ((await row.get_attribute("data-group-code")) or "").strip().casefold()
            checkbox_value = ((await row.locator("input[type='checkbox']").first.get_attribute("value")) or "").strip().casefold()
            text = (await row.inner_text()).casefold()

            if target_class and class_code == target_class:
                matches.append(row)
            elif target_group and course_code == target_course and group_code == target_group:
                matches.append(row)
            elif not target_class and not target_group and course_code == target_course:
                matches.append(row)
            elif checkbox_value and checkbox_value == target_course:
                matches.append(row)
            elif target_course in text and (not target_class or target_class in text):
                matches.append(row)
        return matches

    async def _wait_for_login_outcome(self, page: object) -> None:
        deadline = asyncio.get_running_loop().time() + 15
        while asyncio.get_running_loop().time() < deadline:
            if await self.is_logged_in(page):
                return
            if await self.detect_captcha(page):
                return
            error_text = await self._login_error_text(page)
            if error_text:
                raise AdapterError(ErrorCode.LOGIN_FAILED, error_text)
            await asyncio.sleep(0.2)
        raise AdapterError(ErrorCode.LOGIN_FAILED, "Login did not complete before timeout")

    async def _login_error_text(self, page: object) -> str:
        error_locator = page.locator(self.selectors.login_error)
        if await error_locator.count() == 0:
            return ""
        text = (await error_locator.first.inner_text()).strip()
        return text

    async def _is_control_selected(self, locator: object) -> bool:
        try:
            return await locator.is_checked()
        except PlaywrightError:
            aria_checked = await locator.get_attribute("aria-checked")
            return aria_checked == "true"

    async def _handle_registration_dialog(self, dialog: object) -> None:
        message = dialog.message.casefold()
        expected = ("confirm", "yes", "đăng ký", "xac nhan", "xác nhận", "chắc chắn")
        if dialog.type == "confirm" and any(keyword in message for keyword in expected):
            await dialog.accept()
            return
        await dialog.dismiss()

    async def _goto(self, page: object, url: str, default_error: ErrorCode) -> None:
        try:
            response = await page.goto(url, wait_until="domcontentloaded", timeout=30_000)
        except PlaywrightTimeoutError as exc:
            raise AdapterError(default_error, f"Timed out opening {url}") from exc
        except PlaywrightError as exc:
            raise AdapterError(ErrorCode.NETWORK_ERROR, str(exc)) from exc

        if response is None:
            return

        status = response.status
        if status == 401:
            raise AdapterError(ErrorCode.SESSION_EXPIRED, "Authentication required")
        if status == 403:
            raise AdapterError(ErrorCode.REGISTRATION_PAGE_FAILED, "Access forbidden")
        if status == 404:
            raise AdapterError(default_error, "Page not found")
        if status == 429:
            raise AdapterError(ErrorCode.RATE_LIMITED, "Rate limited")
        if status >= 500:
            raise AdapterError(ErrorCode.SERVER_ERROR, f"Server error HTTP {status}")


def _parse_int(value: str | None) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except ValueError:
        return None
