from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass


@dataclass(slots=True)
class RetryPolicy:
    max_ui_retries: int = 2
    delays: tuple[float, ...] = (0.2, 0.5)


async def retry_ui_action(action: Callable[[], Awaitable[object]], policy: RetryPolicy) -> object:
    attempts = policy.max_ui_retries + 1
    last_error: Exception | None = None
    for index in range(attempts):
        try:
            return await action()
        except TimeoutError as exc:
            last_error = exc
        except RuntimeError as exc:
            last_error = exc
        if index < len(policy.delays):
            await asyncio.sleep(policy.delays[index])
    if last_error is not None:
        raise last_error
    raise RuntimeError("Retry failed without a captured error")
