import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/account_settings.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  static const String _usernameKey = 'account.username';
  static const String _passwordKey = 'account.password';
  static const String _rememberUsernameKey = 'account.rememberUsername';
  static const String _rememberPasswordKey = 'account.rememberPassword';

  final FlutterSecureStorage _storage;

  Future<AccountSettings> loadAccountSettings() async {
    final rememberUsername =
        await _storage.read(key: _rememberUsernameKey) == 'true';
    final rememberPassword =
        await _storage.read(key: _rememberPasswordKey) == 'true';
    return AccountSettings(
      username: rememberUsername
          ? (await _storage.read(key: _usernameKey)) ?? ''
          : '',
      rememberUsername: rememberUsername,
      rememberPassword: rememberPassword,
    );
  }

  Future<String> loadPasswordIfRemembered() async {
    final rememberPassword =
        await _storage.read(key: _rememberPasswordKey) == 'true';
    if (!rememberPassword) {
      return '';
    }
    return await _storage.read(key: _passwordKey) ?? '';
  }

  Future<void> saveAccount({
    required String username,
    required String password,
    required bool rememberUsername,
    required bool rememberPassword,
  }) async {
    await _storage.write(
      key: _rememberUsernameKey,
      value: rememberUsername.toString(),
    );
    await _storage.write(
      key: _rememberPasswordKey,
      value: rememberPassword.toString(),
    );

    if (rememberUsername) {
      await _storage.write(key: _usernameKey, value: username);
    } else {
      await _storage.delete(key: _usernameKey);
    }

    if (rememberPassword) {
      await _storage.write(key: _passwordKey, value: password);
    } else {
      await _storage.delete(key: _passwordKey);
    }
  }
}
