from __future__ import annotations

from app.models.result import CourseResult, RegistrationResult
from app.models.state import ResultStatus


SUCCESS_KEYWORDS = ("đăng ký thành công", "ghi nhận thành công", "đã đăng ký", "success", "registered successfully")
FULL_KEYWORDS = ("hết chỗ", "lớp đầy", "đủ số lượng", "full", "capacity reached")
CONFLICT_KEYWORDS = ("trùng lịch", "trùng giờ", "schedule conflict")
PREREQUISITE_KEYWORDS = ("môn tiên quyết", "học phần tiên quyết", "prerequisite")
ERROR_KEYWORDS = ("thất bại", "failed", "error", "lỗi")


def classify_text(text: str) -> ResultStatus:
    lower = text.casefold()
    if any(keyword in lower for keyword in SUCCESS_KEYWORDS):
        return ResultStatus.SUCCESS
    if any(keyword in lower for keyword in FULL_KEYWORDS):
        return ResultStatus.FULL
    if any(keyword in lower for keyword in CONFLICT_KEYWORDS):
        return ResultStatus.CONFLICT
    if any(keyword in lower for keyword in PREREQUISITE_KEYWORDS):
        return ResultStatus.PREREQUISITE_ERROR
    if any(keyword in lower for keyword in ERROR_KEYWORDS):
        return ResultStatus.UNKNOWN_ERROR
    return ResultStatus.UNKNOWN_RESULT


def build_single_result(course_code: str, class_code: str | None, text: str) -> RegistrationResult:
    status = classify_text(text)
    return RegistrationResult(
        overall_status=status,
        course_results=[CourseResult(course_code=course_code, class_code=class_code, status=status, message=text)],
        message=text,
    )
