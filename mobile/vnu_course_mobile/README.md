# VNU Course Mobile - Phase 1 WebView PoC

This project is a Flutter mobile proof of concept progressing through the safe
local phases. It does not contain Selenium, Playwright, ChromeDriver, a backend,
real registration selectors, CAPTCHA bypass code, or production submit logic.

Phase 1 validates the browser substrate:

- home screen with an Open Login Test action
- one persistent `WebViewController`
- Android System WebView / iOS WKWebView
- desktop-mode user agent
- Android wide viewport
- JavaScript enabled
- persistent platform cookie/session store
- current URL debug display
- fullscreen verification WebView
- close/back handling that preserves the controller
- sanitized in-app logs

Phase 2-3 additions now included:

- central `AutomationController`
- explicit login/session states
- VNU login selector adapter for username/password autofill only
- CAPTCHA detection that pauses for manual user verification
- no Turnstile iframe manipulation and no token handling
- secure storage wrapper for username/password remember settings
- 20-minute local session tracking after login is confirmed
- keep-screen-awake toggle while CAPTCHA is required

Phase-independent foundations now included:

- pre-login safety calculation
- course and course target models
- priority sorting and ambiguity-aware course matching
- retry policy constants
- scheduler sleep interval and clock-jump detection helpers

Real VNU course registration remains intentionally blocked until the actual
registration page DOM/HTML is inspected.

## Existing Python Mapping

The relevant desktop concepts are:

- `app/automation/browser.py`: persistent browser profile. Replaced here by the
  system WebView cookie/session store.
- `app/automation/captcha.py` and `app/automation/login.py`: manual CAPTCHA
  handoff. The mobile app can fill credentials, but the user must complete
  Turnstile manually in the same WebView.
- `app/utils/security.py` and `app/utils/logger.py`: sensitive log redaction and
  millisecond timestamps. Ported as small local Dart utilities.
- `app/automation/scheduler.py`: scheduler interval and clock jump concepts.
- `app/models/course.py`: `Course`, `CourseTarget`, priority, and matching
  semantics.

Everything related to PySide6, Playwright, browser discovery, real course
scan/select/submit, and real result parsing stays out until the corresponding
mobile phase has the required data and device verification.

## Bootstrap Native Runners

This repository was scaffolded in an environment without the Flutter SDK, so the
generated Android and iOS runner folders are intentionally not hand-written.
After installing Flutter, run:

```powershell
cd C:\Users\PC\Documents\bypass.exe\mobile\vnu_course_mobile
flutter create --platforms=android,ios .
flutter pub get
```

Then confirm the generated platform settings:

- Android min SDK must be 24 or newer for current `webview_flutter`.
- iOS deployment target must be 13.0 or newer.
- Android `android/app/src/main/AndroidManifest.xml` must include internet
  permission:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Run Android

```powershell
cd C:\Users\PC\Documents\bypass.exe\mobile\vnu_course_mobile
flutter pub get
flutter run -d <android-device-id>
```

## Run iOS

On macOS with Xcode and signing configured:

```bash
cd /path/to/bypass.exe/mobile/vnu_course_mobile
flutter pub get
flutter run -d <ios-device-id>
```

Use a physical iPhone for the Turnstile/session viability test.

## Build IPA Without Owning a Mac

Use the root `codemagic.yaml` workflow named:

```text
iOS AltStore unsigned IPA
```

It runs on Codemagic macOS/Xcode infrastructure and exports an unsigned IPA that
can be installed through AltStore. See `ALTSTORE_CODEMAGIC.md`.

## Checks

```powershell
flutter format lib test
flutter analyze
flutter test
```

These commands could not be run in the current workspace because `flutter` and
`dart` are not installed.

The existing Python desktop test suite can be run from the workspace root:

```powershell
.\.venv\Scripts\python.exe -m pytest app\tests
```

It passed after the mobile changes.

## Physical Device Checklist

1. Tap Open Login Test.
2. Confirm the VNU login page loads in desktop layout.
3. Confirm JavaScript-dependent page content renders.
4. Complete Turnstile manually in the WebView.
5. Log in manually.
6. Close the fullscreen WebView with the app close button.
7. Reopen fullscreen verification and confirm the authenticated session remains.
8. Use device back navigation inside the fullscreen WebView; page history should
   go back before the route closes.
9. Background and foreground the app briefly, then verify the current URL/session.
10. Export/copy visible logs and confirm no password, cookie, token, or
    authorization value is present.

## Phase 2-3 Login Checklist

1. Open the VNU login page.
2. Enter username/password in the app fields.
3. Leave Remember password off unless explicitly needed.
4. Tap Autofill.
5. Confirm the values appear in the VNU login form.
6. Confirm Turnstile is still manual.
7. Complete CAPTCHA and login inside the WebView.
8. Tap Check Login.
9. Confirm state becomes `LOGIN_SUCCESS`.
10. Confirm login time, expiry time, and remaining countdown are shown.

## Blocked Before Phase 4

Do not implement real course scan/select/submit until one of these is available:

- actual VNU registration page HTML
- a sanitized DOM snapshot
- screenshots plus enough inspected element attributes
- confirmed physical-device WebView behavior after manual Turnstile
