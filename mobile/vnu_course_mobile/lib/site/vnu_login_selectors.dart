class VnuLoginSelectors {
  const VnuLoginSelectors();

  List<String> get username => const <String>[
        '#LoginName',
        'input[name="LoginName"]',
        'input[name="username"]',
        'input[type="text"]',
      ];

  List<String> get password => const <String>[
        '#Password',
        'input[name="Password"]',
        'input[name="password"]',
        'input[type="password"]',
      ];

  List<String> get loginButton => const <String>[
        'form[action*="dang-nhap"] button[type="submit"]',
        'button[type="submit"]',
        'button.btn-success',
        'input[type="submit"]',
      ];

  List<String> get captchaMarkers => const <String>[
        'iframe[src*="turnstile"]',
        '#cf-turnstile',
        '#CloudfareTurnstileResponse',
        '[name="cf-turnstile-response"]',
      ];

  List<String> get loggedInMarkers => const <String>[
        'a[href*="dang-xuat"]',
        'a[href*="logout"]',
        'a[href*="Logout"]',
        '.navbar a[href*="Account"]',
      ];

  List<String> get loginErrors => const <String>[
        '.validation-summary-errors',
        '.field-validation-error',
        '.field-validation-valid.has-error',
        '[role="alert"]',
        '.alert-danger',
      ];
}
