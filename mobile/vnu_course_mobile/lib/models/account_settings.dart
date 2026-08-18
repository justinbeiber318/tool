class AccountSettings {
  const AccountSettings({
    required this.username,
    required this.rememberUsername,
    required this.rememberPassword,
  });

  final String username;
  final bool rememberUsername;
  final bool rememberPassword;
}
