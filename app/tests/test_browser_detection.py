from __future__ import annotations

from app.automation.browser import BrowserDiscovery


def test_browser_detection_prefers_first_existing_path(tmp_path) -> None:
    chrome = tmp_path / "chrome.exe"
    edge = tmp_path / "msedge.exe"
    chrome.write_text("", encoding="utf-8")
    edge.write_text("", encoding="utf-8")

    discovery = BrowserDiscovery((str(chrome), str(edge)))

    candidate = discovery.detect()
    assert candidate is not None
    assert candidate.name == "Chrome"
    assert candidate.executable_path == chrome


def test_validate_user_path_rejects_non_browser_exe(tmp_path) -> None:
    app = tmp_path / "not-browser.exe"
    app.write_text("", encoding="utf-8")

    assert BrowserDiscovery().validate_user_path(str(app)) is None
