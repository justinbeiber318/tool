from __future__ import annotations

import argparse
import html
import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


HOST = "127.0.0.1"
DEFAULT_PORT = 8765


COURSES = [
    {"course": "INT1234", "class": "123456", "group": "01", "name": "Python Basics", "slots": 12, "disabled": False, "full": False},
    {"course": "INT2345", "class": "123457", "group": "01", "name": "Data Structures", "slots": 0, "disabled": False, "full": True},
    {"course": "INT3456", "class": "123458", "group": "02", "name": "Operating Systems", "slots": 8, "disabled": True, "full": False},
    {"course": "INT9999", "class": "223456", "group": "01", "name": "Duplicate A", "slots": 4, "disabled": False, "full": False},
    {"course": "INT9999", "class": "223457", "group": "02", "name": "Duplicate B", "slots": 4, "disabled": False, "full": False},
]


class MockSiteHandler(BaseHTTPRequestHandler):
    server_version = "MockUniversity/0.1"

    def log_message(self, format: str, *args: object) -> None:
        return

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        mode = query.get("mode", ["normal"])[0]

        if parsed.path == "/":
            self._send_html(self._dashboard())
        elif parsed.path == "/login":
            if self._is_logged_in() and mode != "force_login":
                self._redirect("/registration")
                return
            self._send_html(self._login_page(mode))
        elif parsed.path == "/captcha-complete":
            self.send_response(HTTPStatus.SEE_OTHER)
            self.send_header("Set-Cookie", "mock_session=ok; HttpOnly; SameSite=Lax")
            self.send_header("Location", "/registration")
            self.end_headers()
        elif parsed.path == "/registration":
            if mode == "maintenance":
                self._send_html(self._message_page("Maintenance", "Hệ thống đang bảo trì"), HTTPStatus.SERVICE_UNAVAILABLE)
            elif mode == "server500":
                self._send_html(self._message_page("Server error", "Lỗi máy chủ"), HTTPStatus.INTERNAL_SERVER_ERROR)
            elif mode == "rate429":
                self._send_html(self._message_page("Rate limited", "Too Many Requests"), HTTPStatus.TOO_MANY_REQUESTS)
            elif not self._is_logged_in():
                self._redirect("/login")
            elif mode == "closed":
                self._send_html(self._message_page("Registration closed", "Đã hết thời gian đăng ký"))
            elif mode == "not_open":
                self._send_html(self._message_page("Registration not open", "Chưa đến thời gian đăng ký"))
            elif mode == "iframe":
                self._send_html(self._iframe_page(mode))
            elif mode == "frame-content":
                self._send_html(self._registration_page("normal"))
            else:
                self._send_html(self._registration_page(mode))
        elif parsed.path == "/api/debug":
            body = json.dumps({"status": "ok", "modes": self._modes()}, ensure_ascii=False).encode("utf-8")
            self._send_bytes(body, "application/json")
        else:
            self._send_html(self._message_page("Not found", "404"), HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8")
        form = parse_qs(body)

        if parsed.path == "/login":
            username = form.get("username", [""])[0]
            password = form.get("password", [""])[0]
            mode = form.get("mode", ["normal"])[0]
            if mode == "captcha":
                self._send_html(self._login_page(mode, "CAPTCHA đang yêu cầu xác minh."))
                return
            if username and password == "password":
                self.send_response(HTTPStatus.SEE_OTHER)
                self.send_header("Set-Cookie", "mock_session=ok; HttpOnly; SameSite=Lax")
                self.send_header("Location", "/registration")
                self.end_headers()
            else:
                self._send_html(self._login_page(mode, "Sai tài khoản hoặc mật khẩu."))
        elif parsed.path == "/register":
            selected = form.get("course", [])
            if not selected:
                self._send_html(self._registration_page("normal", "UNKNOWN_RESULT: No course selected"))
                return
            result = "Đăng ký thành công: " + ", ".join(html.escape(item) for item in selected)
            self._send_html(self._registration_page("normal", result))
        else:
            self._send_html(self._message_page("Not found", "404"), HTTPStatus.NOT_FOUND)

    def _is_logged_in(self) -> bool:
        return "mock_session=ok" in self.headers.get("Cookie", "")

    def _redirect(self, location: str) -> None:
        self.send_response(HTTPStatus.SEE_OTHER)
        self.send_header("Location", location)
        self.end_headers()

    def _send_html(self, body: str, status: HTTPStatus = HTTPStatus.OK) -> None:
        self._send_bytes(body.encode("utf-8"), "text/html; charset=utf-8", status)

    def _send_bytes(self, body: bytes, content_type: str, status: HTTPStatus = HTTPStatus.OK) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Date", self.date_time_string())
        self.end_headers()
        self.wfile.write(body)

    def _dashboard(self) -> str:
        links = "\n".join(f"<li><a href='/login?mode={mode}'>{mode}</a></li>" for mode in self._modes())
        return self._shell(
            "Mock university dashboard",
            f"""
            <h1>Mock university dashboard</h1>
            <p>Login with any username and password <code>password</code>.</p>
            <ul>{links}</ul>
            """,
        )

    def _login_page(self, mode: str, error: str = "") -> str:
        captcha = ""
        if mode == "captcha":
            captcha = """
            <section id="captcha-box" class="captcha">
              <iframe title="mock recaptcha" src="https://example.test/recaptcha"></iframe>
              <p>CAPTCHA đang yêu cầu xác minh.</p>
              <p><a href="/captcha-complete">Hoàn tất CAPTCHA thủ công</a></p>
            </section>
            """
        return self._shell(
            "Login",
            f"""
            <h1>Đăng nhập</h1>
            <form method="post" action="/login">
              <input type="hidden" name="mode" value="{html.escape(mode)}">
              <label>Username <input id="username" name="username" autocomplete="username"></label>
              <label>Password <input id="password" name="password" type="password" autocomplete="current-password"></label>
              <button type="submit">Đăng nhập</button>
            </form>
            {captcha}
            <p class="error">{html.escape(error)}</p>
            """,
        )

    def _registration_page(self, mode: str, result: str = "") -> str:
        rows = "\n".join(self._course_row(course) for course in COURSES)
        delayed_script = ""
        table_style = ""
        if mode == "delayed":
            table_style = "hidden"
            delayed_script = "setTimeout(() => document.querySelector('#courses').hidden = false, 1500);"
        if mode == "rerender":
            delayed_script = """
            setTimeout(() => {
              const tbody = document.querySelector('tbody');
              tbody.innerHTML = tbody.innerHTML;
            }, 900);
            """
        confirm_script = """
        document.querySelector('#register-form').addEventListener('submit', (event) => {
          if (!window.confirm('Bạn có chắc chắn muốn đăng ký?')) {
            event.preventDefault();
          }
        });
        """
        return self._shell(
            "Registration",
            f"""
            <main data-testid="logged-in">
              <section data-testid="registration-page">
                <h1>Đăng ký học</h1>
                <form id="register-form" method="post" action="/register">
                  <table id="courses" {table_style}>
                    <thead>
                      <tr><th>Mã môn</th><th>Mã lớp</th><th>Nhóm</th><th>Môn học</th><th>Chỗ</th><th>Chọn</th></tr>
                    </thead>
                    <tbody>{rows}</tbody>
                  </table>
                  <button type="submit">Ghi nhận</button>
                </form>
                <output data-testid="result">{html.escape(result)}</output>
              </section>
            </main>
            <script>{delayed_script}{confirm_script}</script>
            """,
        )

    def _course_row(self, course: dict[str, object]) -> str:
        disabled = "disabled" if course["disabled"] else ""
        aria_disabled = "true" if course["disabled"] else "false"
        full = "true" if course["full"] else "false"
        return f"""
        <tr data-course-row
            data-course-code="{course['course']}"
            data-class-code="{course['class']}"
            data-group-code="{course['group']}"
            data-available-slots="{course['slots']}"
            data-full="{full}"
            aria-disabled="{aria_disabled}">
          <td>{course['course']}</td>
          <td>{course['class']}</td>
          <td>{course['group']}</td>
          <td>{course['name']}</td>
          <td>{course['slots']}</td>
          <td><input type="checkbox" name="course" value="{course['course']}:{course['class']}" {disabled}></td>
        </tr>
        """

    def _iframe_page(self, mode: str) -> str:
        return self._shell(
            "Registration iframe",
            """
            <main data-testid="logged-in">
              <iframe title="registration-frame" src="/registration?mode=frame-content" width="100%" height="460"></iframe>
            </main>
            """,
        )

    def _message_page(self, title: str, message: str) -> str:
        return self._shell(title, f"<h1>{html.escape(title)}</h1><p>{html.escape(message)}</p>")

    def _shell(self, title: str, body: str) -> str:
        return f"""
        <!doctype html>
        <html lang="vi">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>{html.escape(title)}</title>
            <style>
              body {{ font-family: Segoe UI, Arial, sans-serif; margin: 32px; line-height: 1.5; }}
              form {{ display: grid; gap: 14px; max-width: 920px; }}
              label {{ display: grid; gap: 6px; max-width: 420px; }}
              input, button {{ font: inherit; padding: 8px 10px; }}
              table {{ border-collapse: collapse; width: 100%; margin: 12px 0; }}
              th, td {{ border: 1px solid #ccc; padding: 8px; text-align: left; }}
              .error {{ color: #b00020; }}
              output {{ display: block; margin-top: 16px; font-weight: 600; }}
            </style>
          </head>
          <body>{body}</body>
        </html>
        """

    def _modes(self) -> list[str]:
        return [
            "normal",
            "captcha",
            "delayed",
            "rerender",
            "iframe",
            "maintenance",
            "not_open",
            "closed",
            "rate429",
            "server500",
        ]


def run(host: str = HOST, port: int = DEFAULT_PORT) -> None:
    server = ThreadingHTTPServer((host, port), MockSiteHandler)
    print(f"Mock university site: http://{host}:{port}")
    server.serve_forever()


def main() -> int:
    parser = argparse.ArgumentParser(description="Run local mock university website.")
    parser.add_argument("--host", default=HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    run(args.host, args.port)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
