from __future__ import annotations

import asyncio
import inspect
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import datetime


CountdownCallback = Callable[[float], Awaitable[None] | None]


@dataclass(slots=True)
class WaitResult:
    reached: bool
    late_by_seconds: float = 0.0
    clock_jump_detected: bool = False


def next_sleep_interval(remaining_seconds: float) -> float:
    if remaining_seconds > 60:
        return 1.0
    if remaining_seconds > 5:
        return 0.2
    return 0.05


async def wait_until(
    target: datetime,
    *,
    allow_late_execution: bool = False,
    on_countdown: CountdownCallback | None = None,
    cancel_event: asyncio.Event | None = None,
) -> WaitResult:
    last_wall = datetime.now()
    last_mono = time.monotonic()
    clock_jump_detected = False

    while True:
        now = datetime.now()
        remaining = (target - now).total_seconds()
        if on_countdown is not None:
            maybe_awaitable = on_countdown(max(0.0, remaining))
            if inspect.isawaitable(maybe_awaitable):
                await maybe_awaitable

        if remaining <= 0:
            late_by = abs(remaining)
            if late_by > 2 and not allow_late_execution:
                return WaitResult(False, late_by_seconds=late_by, clock_jump_detected=clock_jump_detected)
            return WaitResult(True, late_by_seconds=late_by, clock_jump_detected=clock_jump_detected)

        if cancel_event is not None and cancel_event.is_set():
            return WaitResult(False, clock_jump_detected=clock_jump_detected)

        interval = next_sleep_interval(remaining)
        await asyncio.sleep(interval)

        wall_delta = (datetime.now() - last_wall).total_seconds()
        mono_delta = time.monotonic() - last_mono
        if abs(wall_delta - mono_delta) > 2:
            clock_jump_detected = True
        last_wall = datetime.now()
        last_mono = time.monotonic()
