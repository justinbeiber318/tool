from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from app.models.config import BrowserSettings
from app.models.state import ErrorCode


WINDOWS_BROWSER_PATHS = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
)


class BrowserError(RuntimeError):
    def __init__(self, code: ErrorCode, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(slots=True)
class BrowserCandidate:
    name: str
    executable_path: Path


class BrowserDiscovery:
    def __init__(self, paths: tuple[str, ...] = WINDOWS_BROWSER_PATHS) -> None:
        self.paths = paths

    def detect(self) -> BrowserCandidate | None:
        for raw_path in self.paths:
            path = Path(raw_path)
            if path.exists() and path.is_file():
                name = "Edge" if "Edge" in raw_path or "msedge" in raw_path.lower() else "Chrome"
                return BrowserCandidate(name=name, executable_path=path)
        return None

    def validate_user_path(self, raw_path: str) -> BrowserCandidate | None:
        path = Path(raw_path).expanduser()
        if not path.exists() or not path.is_file():
            return None
        filename = path.name.lower()
        if filename not in {"chrome.exe", "msedge.exe", "chromium.exe"}:
            return None
        if "msedge" in filename:
            name = "Edge"
        elif "chromium" in filename:
            name = "Chromium"
        else:
            name = "Chrome"
        return BrowserCandidate(name=name, executable_path=path)


class BrowserManager:
    def __init__(self, settings: BrowserSettings, discovery: BrowserDiscovery | None = None) -> None:
        self.settings = settings
        self.discovery = discovery or BrowserDiscovery()
        self._playwright = None
        self.context = None
        self.page = None

    def resolve_browser(self) -> BrowserCandidate | None:
        if self.settings.executable_path:
            selected = self.discovery.validate_user_path(self.settings.executable_path)
            if selected is not None:
                return selected
        return self.discovery.detect()

    async def start(self) -> object:
        try:
            from playwright.async_api import async_playwright
        except ImportError as exc:
            raise BrowserError(
                ErrorCode.BROWSER_START_FAILED,
                "Playwright is not installed. Run: pip install -r requirements.txt",
            ) from exc

        user_data_dir = Path(self.settings.user_data_dir)
        user_data_dir.mkdir(parents=True, exist_ok=True)

        self._playwright = await async_playwright().start()
        candidate = self.resolve_browser()
        launch_options = {
            "headless": False,
            "user_data_dir": str(user_data_dir),
            "accept_downloads": False,
        }

        try:
            if candidate is not None:
                launch_options["executable_path"] = str(candidate.executable_path)
                self.context = await self._playwright.chromium.launch_persistent_context(**launch_options)
            elif self.settings.allow_bundled_chromium:
                self.context = await self._playwright.chromium.launch_persistent_context(**launch_options)
            else:
                raise BrowserError(
                    ErrorCode.BROWSER_NOT_FOUND,
                    "Không tìm thấy Chrome hoặc Edge. Hãy chọn browser.exe trong Settings.",
                )
        except BrowserError:
            await self.stop()
            raise
        except Exception as exc:
            await self.stop()
            raise BrowserError(ErrorCode.BROWSER_START_FAILED, str(exc)) from exc

        self.page = self.context.pages[0] if self.context.pages else await self.context.new_page()
        return self.page

    async def stop(self) -> None:
        context = self.context
        self.context = None
        self.page = None
        if context is not None:
            await context.close()
        if self._playwright is not None:
            await self._playwright.stop()
            self._playwright = None


def is_windows_64bit() -> bool:
    return os.name == "nt" and os.environ.get("PROCESSOR_ARCHITECTURE", "").endswith("64")
