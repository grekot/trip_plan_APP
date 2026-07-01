import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Bezpieczne przechowywanie hasła deszyfrującego plany.
/// Android: EncryptedSharedPreferences/Keystore. Windows: DPAPI/Credential Manager.
class PassphraseStore {
  static const _key = 'plan_passphrase';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> get() => _storage.read(key: _key);
  static Future<void> set(String passphrase) =>
      _storage.write(key: _key, value: passphrase);
  static Future<void> clear() => _storage.delete(key: _key);
  static Future<bool> has() async {
    final v = await get();
    return v != null && v.isNotEmpty;
  }
}
