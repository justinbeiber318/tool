from __future__ import annotations

import re
from dataclasses import dataclass


COURSE_TOKEN_RE = re.compile(r"^[A-Za-z0-9_.-]{2,32}$")


@dataclass(slots=True)
class Course:
    course_code: str | None = None
    course_name: str | None = None
    class_code: str | None = None
    group_code: str | None = None
    lecturer: str | None = None
    credits: int | None = None
    capacity: int | None = None
    registered: int | None = None
    available_slots: int | None = None
    raw_text: str = ""


@dataclass(slots=True)
class CourseTarget:
    course_code: str
    class_code: str | None = None
    group_code: str | None = None
    priority: int = 1

    def normalized_key(self) -> tuple[str, str, str]:
        return (
            self.course_code.strip().upper(),
            (self.class_code or "").strip().upper(),
            (self.group_code or "").strip().upper(),
        )

    def validate(self) -> list[str]:
        errors: list[str] = []
        if not self.course_code.strip():
            errors.append("Course code is required")
        if self.course_code and not COURSE_TOKEN_RE.match(self.course_code.strip()):
            errors.append(f"Malformed course code: {self.course_code}")
        if self.class_code and not COURSE_TOKEN_RE.match(self.class_code.strip()):
            errors.append(f"Malformed class code: {self.class_code}")
        if self.group_code and not COURSE_TOKEN_RE.match(self.group_code.strip()):
            errors.append(f"Malformed group code: {self.group_code}")
        if self.priority < 1:
            errors.append("Priority must be 1 or greater")
        return errors


def parse_course_lines(text: str) -> list[CourseTarget]:
    targets: list[CourseTarget] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        parts = re.split(r"[\t,;| ]+", line)
        if not parts:
            continue
        priority = 1
        if len(parts) >= 4 and parts[3].isdigit():
            priority = int(parts[3])
        targets.append(
            CourseTarget(
                course_code=parts[0],
                class_code=parts[1] if len(parts) >= 2 and parts[1] else None,
                group_code=parts[2] if len(parts) >= 3 and parts[2] else None,
                priority=priority,
            )
        )
    return targets
