from __future__ import annotations

from datetime import datetime, timedelta

import pytest

from app.automation.scheduler import next_sleep_interval, wait_until


def test_next_sleep_interval_scales_by_remaining_time() -> None:
    assert next_sleep_interval(61) == 1.0
    assert next_sleep_interval(10) == 0.2
    assert next_sleep_interval(4) == 0.05


@pytest.mark.asyncio
async def test_wait_until_rejects_late_execution_by_default() -> None:
    result = await wait_until(datetime.now() - timedelta(seconds=3))

    assert result.reached is False
    assert result.late_by_seconds >= 2
