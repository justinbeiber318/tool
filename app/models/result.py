from __future__ import annotations

from dataclasses import dataclass, field

from app.models.state import ResultStatus


@dataclass(slots=True)
class CourseResult:
    course_code: str
    class_code: str | None
    status: ResultStatus
    message: str = ""


@dataclass(slots=True)
class RegistrationResult:
    overall_status: ResultStatus
    course_results: list[CourseResult] = field(default_factory=list)
    message: str = ""
