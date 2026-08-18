from __future__ import annotations

import logging

from app.adapters.generic import AdapterError
from app.adapters.base import SiteAdapter
from app.models.course import CourseTarget
from app.models.result import CourseResult, RegistrationResult
from app.models.state import ErrorCode, ResultStatus


logger = logging.getLogger(__name__)


ERROR_STATUS_BY_CODE: dict[ErrorCode, ResultStatus] = {
    ErrorCode.COURSE_NOT_FOUND: ResultStatus.COURSE_NOT_FOUND,
    ErrorCode.COURSE_AMBIGUOUS: ResultStatus.COURSE_AMBIGUOUS,
    ErrorCode.COURSE_DISABLED: ResultStatus.COURSE_DISABLED,
    ErrorCode.COURSE_FULL: ResultStatus.FULL,
    ErrorCode.SESSION_EXPIRED: ResultStatus.SESSION_EXPIRED,
    ErrorCode.NETWORK_ERROR: ResultStatus.NETWORK_ERROR,
}


async def submit_registration(
    page: object,
    adapter: SiteAdapter,
    targets: list[CourseTarget],
    *,
    strict_mode: bool = True,
) -> RegistrationResult:
    selected: list[CourseTarget] = []
    course_results: list[CourseResult] = []

    for target in sorted(targets, key=lambda item: item.priority):
        try:
            logger.info("Selecting course %s class %s", target.course_code, target.class_code or "")
            await adapter.select_course(page, target)
            selected.append(target)
            course_results.append(
                CourseResult(
                    course_code=target.course_code,
                    class_code=target.class_code,
                    status=ResultStatus.SUCCESS,
                    message="Selected",
                )
            )
        except AdapterError as exc:
            logger.warning("Course selection failed: %s", exc)
            course_results.append(
                CourseResult(
                    course_code=target.course_code,
                    class_code=target.class_code,
                    status=ERROR_STATUS_BY_CODE.get(exc.code, ResultStatus.UNKNOWN_ERROR),
                    message=str(exc),
                )
            )
            if strict_mode:
                return RegistrationResult(
                    overall_status=ResultStatus.UNKNOWN_ERROR,
                    course_results=course_results,
                    message="Strict mode stopped before submit because at least one course was not selectable.",
                )

    if not selected:
        return RegistrationResult(
            overall_status=ResultStatus.UNKNOWN_ERROR,
            course_results=course_results,
            message="No course was selected. Submit skipped.",
        )

    await adapter.submit(page)
    parsed = await adapter.parse_result(page)

    if parsed.overall_status == ResultStatus.SUCCESS:
        failed = [item for item in course_results if item.status != ResultStatus.SUCCESS]
        for item in course_results:
            if item.status == ResultStatus.SUCCESS:
                item.message = "Registered successfully"
        return RegistrationResult(
            overall_status=ResultStatus.PARTIAL_SUCCESS if failed else ResultStatus.SUCCESS,
            course_results=course_results,
            message=parsed.message,
        )

    for item in course_results:
        if item.status == ResultStatus.SUCCESS:
            item.status = parsed.overall_status
            item.message = parsed.message
    return RegistrationResult(
        overall_status=parsed.overall_status,
        course_results=course_results,
        message=parsed.message,
    )
