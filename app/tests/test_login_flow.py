from __future__ import annotations

import pytest

from app.automation.login import LoginFlowError, ensure_logged_in
from app.models.state import ErrorCode


class FakeLoginAdapter:
    registration_mode = "BATCH"

    def __init__(self, *, logged_in: bool = False, captcha_checks_before_clear: int = 0, login_success: bool = True) -> None:
        self.logged_in = logged_in
        self.captcha_checks_before_clear = captcha_checks_before_clear
        self.login_success = login_success
        self.opened_login = False
        self.login_called = False

    async def open_login_page(self, page: object) -> None:
        self.opened_login = True

    async def is_logged_in(self, page: object) -> bool:
        return self.logged_in

    async def login(self, page: object, username: str, password: str) -> None:
        self.login_called = True
        self.logged_in = self.login_success

    async def detect_captcha(self, page: object) -> bool:
        if self.captcha_checks_before_clear > 0:
            self.captcha_checks_before_clear -= 1
            return True
        return False

    async def open_registration_page(self, page: object) -> None:
        pass

    async def is_registration_page(self, page: object) -> bool:
        return True

    async def get_registration_frame(self, page: object) -> object:
        return page

    async def scan_courses(self, page: object) -> list[object]:
        return []

    async def select_course(self, page: object, target: object) -> None:
        pass

    async def submit(self, page: object) -> None:
        pass

    async def parse_result(self, page: object) -> object:
        return object()


@pytest.mark.asyncio
async def test_ensure_logged_in_skips_login_when_session_exists() -> None:
    adapter = FakeLoginAdapter(logged_in=True)

    result = await ensure_logged_in(object(), adapter, "student", "password")

    assert result.logged_in is True
    assert result.already_logged_in is True
    assert adapter.login_called is False


@pytest.mark.asyncio
async def test_ensure_logged_in_raises_for_wrong_password() -> None:
    adapter = FakeLoginAdapter(login_success=False)

    with pytest.raises(LoginFlowError) as error:
        await ensure_logged_in(object(), adapter, "student", "wrong")

    assert error.value.code == ErrorCode.LOGIN_FAILED


@pytest.mark.asyncio
async def test_ensure_logged_in_waits_for_manual_captcha() -> None:
    adapter = FakeLoginAdapter(logged_in=False, captcha_checks_before_clear=1)

    async def complete_captcha() -> None:
        adapter.logged_in = True

    result = await ensure_logged_in(
        object(),
        adapter,
        "student",
        "password",
        poll_seconds=0.01,
        on_captcha_required=complete_captcha,
    )

    assert result.logged_in is True
    assert result.captcha_required is True
