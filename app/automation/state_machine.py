from __future__ import annotations

from dataclasses import dataclass, field

from app.models.state import AutomationState


TERMINAL_STATES = {
    AutomationState.SUCCESS,
    AutomationState.PARTIAL_SUCCESS,
    AutomationState.FAILED,
    AutomationState.STOPPED,
}


ALLOWED_TRANSITIONS: dict[AutomationState, set[AutomationState]] = {
    AutomationState.IDLE: {AutomationState.STARTING_BROWSER, AutomationState.STOPPED},
    AutomationState.STARTING_BROWSER: {AutomationState.OPENING_LOGIN_PAGE, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.OPENING_LOGIN_PAGE: {
        AutomationState.LOGGING_IN,
        AutomationState.CAPTCHA_REQUIRED,
        AutomationState.WAITING_LOGIN,
        AutomationState.OPENING_REGISTRATION_PAGE,
        AutomationState.FAILED,
        AutomationState.STOPPED,
    },
    AutomationState.LOGGING_IN: {AutomationState.CAPTCHA_REQUIRED, AutomationState.OPENING_REGISTRATION_PAGE, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.CAPTCHA_REQUIRED: {AutomationState.WAITING_LOGIN, AutomationState.OPENING_REGISTRATION_PAGE, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.WAITING_LOGIN: {AutomationState.OPENING_REGISTRATION_PAGE, AutomationState.CAPTCHA_REQUIRED, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.OPENING_REGISTRATION_PAGE: {AutomationState.SCANNING, AutomationState.LOGGING_IN, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.SCANNING: {AutomationState.READY, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.READY: {AutomationState.WAITING_TIME, AutomationState.SELECTING, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.WAITING_TIME: {AutomationState.SELECTING, AutomationState.CAPTCHA_REQUIRED, AutomationState.LOGGING_IN, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.SELECTING: {AutomationState.VERIFYING_SELECTION, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.VERIFYING_SELECTION: {AutomationState.SUBMITTING, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.SUBMITTING: {AutomationState.WAITING_CONFIRMATION, AutomationState.WAITING_RESULT, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.WAITING_CONFIRMATION: {AutomationState.WAITING_RESULT, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.WAITING_RESULT: {AutomationState.SUCCESS, AutomationState.PARTIAL_SUCCESS, AutomationState.FAILED, AutomationState.STOPPED},
    AutomationState.SUCCESS: set(),
    AutomationState.PARTIAL_SUCCESS: set(),
    AutomationState.FAILED: set(),
    AutomationState.STOPPED: set(),
}


@dataclass(slots=True)
class StateMachine:
    current: AutomationState = AutomationState.IDLE
    history: list[AutomationState] = field(default_factory=lambda: [AutomationState.IDLE])

    def transition_to(self, next_state: AutomationState) -> None:
        allowed = ALLOWED_TRANSITIONS[self.current]
        if next_state not in allowed:
            raise ValueError(f"Invalid transition from {self.current.value} to {next_state.value}")
        self.current = next_state
        self.history.append(next_state)

    @property
    def is_terminal(self) -> bool:
        return self.current in TERMINAL_STATES
