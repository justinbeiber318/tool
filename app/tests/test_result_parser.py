from __future__ import annotations

from app.automation.result_parser import classify_text
from app.models.state import ResultStatus


def test_result_parser_classifies_success() -> None:
    assert classify_text("Đăng ký thành công") == ResultStatus.SUCCESS


def test_result_parser_classifies_conflict() -> None:
    assert classify_text("Trùng lịch học") == ResultStatus.CONFLICT
