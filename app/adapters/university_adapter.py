from __future__ import annotations

from urllib.parse import urlparse

from app.adapters.generic import GenericSelectors, GenericSiteAdapter
from app.models.config import SiteSettings
from app.models.state import ErrorCode

try:
    from playwright.async_api import TimeoutError as PlaywrightTimeoutError
except ImportError:  # pragma: no cover - exercised only before dependencies are installed.
    PlaywrightTimeoutError = TimeoutError


class UniversityAdapter(GenericSiteAdapter):
    """Configurable adapter placeholder for a real university website.

    Phase 1-3 intentionally keep the selectors centralized and generic. A later
    phase can subclass this adapter with school-specific selectors without
    changing the automation engine.
    """

    def __init__(self, settings: SiteSettings) -> None:
        self.is_vnu_site = _is_vnu_site(settings.login_url)
        super().__init__(
            login_url=settings.login_url,
            registration_url=settings.registration_url,
            registration_mode=settings.registration_mode,
            selectors=_vnu_selectors() if self.is_vnu_site else None,
        )

    async def login(self, page: object, username: str, password: str) -> None:
        if not self.is_vnu_site:
            await super().login(page, username, password)
            return

        user_field = page.locator(self.selectors.username)
        pass_field = page.locator(self.selectors.password)
        try:
            await user_field.wait_for(state="visible", timeout=10_000)
            await pass_field.wait_for(state="visible", timeout=10_000)
        except PlaywrightTimeoutError as exc:
            from app.adapters.generic import AdapterError

            raise AdapterError(ErrorCode.LOGIN_PAGE_FAILED, "VNU login fields did not appear") from exc

        await user_field.fill(username)
        await pass_field.fill(password)

        # VNU shows Cloudflare Turnstile before submit. Leave the browser ready
        # for the user to solve it and press the login button manually.
        if await self.detect_captcha(page):
            return

        await super().login(page, username, password)

    async def detect_captcha(self, page: object) -> bool:
        if not self.is_vnu_site:
            return await super().detect_captcha(page)

        if await page.locator(self.selectors.username).count() > 0:
            username = await page.locator(self.selectors.username).first.input_value()
            if not username:
                return False
            if await page.locator("#cf-turnstile, #CloudfareTurnstileResponse").count() > 0:
                return True

        return await super().detect_captcha(page)


def _is_vnu_site(login_url: str) -> bool:
    return (urlparse(login_url).hostname or "").casefold() == "dangkyhoc.vnu.edu.vn"


def _vnu_selectors() -> GenericSelectors:
    return GenericSelectors(
        username="#LoginName, input[name='LoginName']",
        password="#Password, input[name='Password']",
        login_button="form[action*='dang-nhap'] button[type='submit'], button.btn-success",
        login_error=".validation-summary-errors, .field-validation-error, .field-validation-valid.has-error, [role='alert']",
        logged_in_marker="a[href*='dang-xuat'], a[href*='logout'], body:not(.login)",
        registration_marker="table, form",
    )
