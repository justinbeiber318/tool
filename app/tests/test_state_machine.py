from __future__ import annotations

import pytest

from app.automation.state_machine import StateMachine
from app.models.state import AutomationState


def test_state_machine_allows_expected_transition() -> None:
    machine = StateMachine()

    machine.transition_to(AutomationState.STARTING_BROWSER)

    assert machine.current == AutomationState.STARTING_BROWSER
    assert machine.history == [AutomationState.IDLE, AutomationState.STARTING_BROWSER]


def test_state_machine_rejects_invalid_transition() -> None:
    machine = StateMachine()

    with pytest.raises(ValueError):
        machine.transition_to(AutomationState.SUBMITTING)
