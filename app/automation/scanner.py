from __future__ import annotations

from app.adapters.base import SiteAdapter
from app.models.course import Course


async def scan_courses(page: object, adapter: SiteAdapter) -> list[Course]:
    return await adapter.scan_courses(page)
