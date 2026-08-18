from __future__ import annotations

from abc import ABC, abstractmethod

from app.models.course import Course, CourseTarget
from app.models.result import RegistrationResult


class SiteAdapter(ABC):
    registration_mode: str = "BATCH"

    @abstractmethod
    async def open_login_page(self, page: object) -> None:
        ...

    @abstractmethod
    async def is_logged_in(self, page: object) -> bool:
        ...

    @abstractmethod
    async def login(self, page: object, username: str, password: str) -> None:
        ...

    @abstractmethod
    async def detect_captcha(self, page: object) -> bool:
        ...

    @abstractmethod
    async def open_registration_page(self, page: object) -> None:
        ...

    @abstractmethod
    async def is_registration_page(self, page: object) -> bool:
        ...

    @abstractmethod
    async def get_registration_frame(self, page: object) -> object:
        ...

    @abstractmethod
    async def scan_courses(self, page: object) -> list[Course]:
        ...

    @abstractmethod
    async def select_course(self, page: object, target: CourseTarget) -> None:
        ...

    @abstractmethod
    async def submit(self, page: object) -> None:
        ...

    @abstractmethod
    async def parse_result(self, page: object) -> RegistrationResult:
        ...
