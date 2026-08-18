from __future__ import annotations

import logging
import socket
import threading
from http.server import ThreadingHTTPServer
from urllib.parse import urlparse

from app.models.config import SiteSettings
from app.tests.mock_site.server import DEFAULT_PORT, HOST, MockSiteHandler


logger = logging.getLogger(__name__)

_server: ThreadingHTTPServer | None = None
_thread: threading.Thread | None = None
_lock = threading.Lock()


def ensure_local_mock_site(settings: SiteSettings) -> bool:
    """Start the bundled mock site when config points at its default URL."""
    global _server, _thread

    target = _mock_target(settings)
    if target is None:
        return False

    host, port = target
    if _can_connect(host, port):
        return False

    with _lock:
        if _can_connect(host, port):
            return False
        if _server is not None:
            return True

        _server = ThreadingHTTPServer((host, port), MockSiteHandler)
        _thread = threading.Thread(
            target=_server.serve_forever,
            name="LocalMockUniversitySite",
            daemon=True,
        )
        _thread.start()
        logger.info("Started local mock site at http://%s:%s", host, port)
        return True


def _mock_target(settings: SiteSettings) -> tuple[str, int] | None:
    login = urlparse(settings.login_url)
    registration = urlparse(settings.registration_url)

    if login.scheme != "http" or registration.scheme != "http":
        return None
    if login.hostname not in {HOST, "localhost"}:
        return None
    if registration.hostname not in {HOST, "localhost"}:
        return None
    if (login.port or 80) != DEFAULT_PORT or (registration.port or 80) != DEFAULT_PORT:
        return None
    if login.path != "/login" or registration.path != "/registration":
        return None

    return (login.hostname or HOST, DEFAULT_PORT)


def _can_connect(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.3):
            return True
    except OSError:
        return False
