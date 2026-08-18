from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

from app.adapters.base import SiteAdapter
from app.models.state import ErrorCode


class LoginFlowError(RuntimeError):
    def __init__(self, code: ErrorCode, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(slots=True)
class LoginFlowResult:
    logged_in: bool
    already_logged_in: bool = False
    captcha_required: bool = False
    message: str = ""


CaptchaCallback = Callable[[], Awaitable[None] | None]


async def ensure_logged_in(
    page: object,
    adapter: SiteAdapter,
    username: str,
    password: str,
    *,
    captcha_timeout_seconds: int = 300,
    poll_seconds: float = 0.75,
    on_captcha_required: CaptchaCallback | None = None,
) -> LoginFlowResult:
    await adapter.open_login_page(page)

    if await adapter.is_logged_in(page):
        return LoginFlowResult(logged_in=True, already_logged_in=True, message="Already logged in")

    if await adapter.detect_captcha(page):
        await _notify_captcha(on_captcha_required)
        resolved = await _wait_for_manual_captcha(
            page,
            adapter,
            timeout_seconds=captcha_timeout_seconds,
            poll_seconds=poll_seconds,
        )
        if not resolved:
            raise LoginFlowError(ErrorCode.CAPTCHA_TIMEOUT, "CAPTCHA verification timed out")
        return LoginFlowResult(logged_in=True, captcha_required=True, message="CAPTCHA completed manually")

    await adapter.login(page, username, password)

    if await adapter.detect_captcha(page):
        await _notify_captcha(on_captcha_required)
        resolved = await _wait_for_manual_captcha(
            page,
            adapter,
            timeout_seconds=captcha_timeout_seconds,
            poll_seconds=poll_seconds,
        )
        if not resolved:
            raise LoginFlowError(ErrorCode.CAPTCHA_TIMEOUT, "CAPTCHA verification timed out")
        return LoginFlowResult(logged_in=True, captcha_required=True, message="CAPTCHA completed manually")

    if await adapter.is_logged_in(page):
        return LoginFlowResult(logged_in=True, message="Login successful")

    raise LoginFlowError(ErrorCode.LOGIN_FAILED, "Login failed. Please check username/password or account status.")


async def _notify_captcha(callback: CaptchaCallback | None) -> None:
    if callback is None:
        return
    maybe_awaitable = callback()
    if maybe_awaitable is not None:
        await maybe_awaitable


async def _wait_for_manual_captcha(
    page: object,
    adapter: SiteAdapter,
    *,
    timeout_seconds: int,
    poll_seconds: float,
) -> bool:
    deadline = asyncio.get_running_loop().time() + timeout_seconds
    while asyncio.get_running_loop().time() < deadline:
        if not await adapter.detect_captcha(page) and await adapter.is_logged_in(page):
            return True
        await asyncio.sleep(poll_seconds)
    return False
