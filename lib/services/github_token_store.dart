import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token GitHub (fine-grained PAT z uprawnieniem Contents: Read and write
/// TYLKO do repo trip_plans) — używany do wysyłania planów z aplikacji.
/// Przechowywany w secure storage, jak hasło planów i klucze AI.
class GithubTokenStore {
  static const _key = 'github_push_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> get() => _storage.read(key: _key);

  static Future<void> set(String token) async {
    if (token.trim().isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: token.trim());
    }
  }

  static Future<void> clear() => _storage.delete(key: _key);
}
