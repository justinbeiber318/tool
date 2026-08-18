from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

from app.models.course import CourseTarget


@dataclass(slots=True)
class BrowserSettings:
    executable_path: str | None = None
    allow_bundled_chromium: bool = False
    close_browser_on_stop: bool = True
    user_data_dir: str = "data/browser_profile"


@dataclass(slots=True)
class AutomationSettings:
    strict_mode: bool = True
    allow_late_execution: bool = False
    save_screenshot_on_error: bool = True
    debug_mode: bool = False
    captcha_timeout_seconds: int = 300
    max_ui_retries: int = 2


@dataclass(slots=True)
class SiteSettings:
    login_url: str = "https://dangkyhoc.vnu.edu.vn/dang-nhap"
    registration_url: str = "https://dangkyhoc.vnu.edu.vn/dang-ky-hoc"
    registration_mode: str = "BATCH"


@dataclass(slots=True)
class AppConfig:
    username: str = ""
    remember_username: bool = False
    target_time: datetime | None = None
    courses: list[CourseTarget] = field(default_factory=list)
    browser: BrowserSettings = field(default_factory=BrowserSettings)
    automation: AutomationSettings = field(default_factory=AutomationSettings)
    site: SiteSettings = field(default_factory=SiteSettings)

    def to_safe_dict(self) -> dict[str, Any]:
        data = asdict(self)
        if self.target_time is not None:
            data["target_time"] = self.target_time.isoformat()
        if not self.remember_username:
            data["username"] = ""
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "AppConfig":
        target_time = data.get("target_time")
        courses = [CourseTarget(**item) for item in data.get("courses", [])]
        return cls(
            username=str(data.get("username", "")),
            remember_username=bool(data.get("remember_username", False)),
            target_time=datetime.fromisoformat(target_time) if target_time else None,
            courses=courses,
            browser=BrowserSettings(**data.get("browser", {})),
            automation=AutomationSettings(**data.get("automation", {})),
            site=SiteSettings(**data.get("site", {})),
        )


def default_config_path() -> Path:
    return Path("data") / "config.json"
