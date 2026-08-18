from __future__ import annotations

import asyncio
from typing import Protocol


class LoginStatusProbe(Protocol):
    async def __call__(self) -> bool:
        ...


class CaptchaDetector:
    async def detect(self, page: object) -> bool:
        selectors = [
            "iframe[src*='recaptcha']",
            "iframe[src*='hcaptcha']",
            "iframe[src*='turnstile']",
            "[class*='captcha' i]",
            "[id*='captcha' i]",
            "text=/captcha|xác minh|verify/i",
        ]
        for selector in selectors:
            locator = page.locator(selector)
            if await locator.count() > 0:
                return True
        return False

    async def wait_until_resolved(
        self,
        page: object,
        is_logged_in: LoginStatusProbe,
        *,
        timeout_seconds: int = 300,
        poll_seconds: float = 0.75,
    ) -> bool:
        deadline = asyncio.get_running_loop().time() + timeout_seconds
        while asyncio.get_running_loop().time() < deadline:
            if not await self.detect(page) and await is_logged_in():
                return True
            await asyncio.sleep(poll_seconds)
        return False
