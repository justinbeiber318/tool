from __future__ import annotations

from app.models.course import CourseTarget, parse_course_lines


def test_parse_course_lines_accepts_multiple_formats() -> None:
    targets = parse_course_lines("INT1234 123456 01 1\nINT2345,123457,02,2")

    assert targets == [
        CourseTarget(course_code="INT1234", class_code="123456", group_code="01", priority=1),
        CourseTarget(course_code="INT2345", class_code="123457", group_code="02", priority=2),
    ]


def test_course_target_validation_rejects_empty_course_code() -> None:
    target = CourseTarget(course_code="", class_code="123456")

    assert "Course code is required" in target.validate()
