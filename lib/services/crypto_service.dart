import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Szyfrowanie/odszyfrowanie planów podróży.
///
/// Schemat: AES-256-GCM (uwierzytelnione), klucz wyprowadzany z hasła przez
/// PBKDF2-HMAC-SHA256 (200k iteracji). Czysty Dart (bez zależności od Fluttera),
/// więc tego samego kodu używa narzędzie `tool/encrypt_plan.dart` po stronie PC —
/// gwarancja, że format zaszyfrowany przez PC odszyfruje się w apce.
///
/// Format envelope (JSON): { v, kdf, iter, salt, cipher, nonce, ct, mac }
/// (salt/nonce/ct/mac w base64).
class CryptoService {
  static const int iterations = 200000;
  static const int saltLen = 16;
  static const int nonceLen = 12;
  static const String kdfName = 'PBKDF2-HMAC-SHA256';
  static const String cipherName = 'AES-256-GCM';

  static final _aes = AesGcm.with256bits();

  static Pbkdf2 _kdf(int iter) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iter, bits: 256);

  /// Szyfruje [plaintext] (UTF-8) hasłem [passphrase]. Zwraca envelope jako JSON.
  static Future<String> encrypt(String plaintext, String passphrase) async {
    final rng = Random.secure();
    final salt =
        Uint8List.fromList(List.generate(saltLen, (_) => rng.nextInt(256)));
    final nonce =
        Uint8List.fromList(List.generate(nonceLen, (_) => rng.nextInt(256)));
    final key = await _kdf(iterations)
        .deriveKeyFromPassword(password: passphrase, nonce: salt);
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    final env = <String, dynamic>{
      'v': 1,
      'kdf': kdfName,
      'iter': iterations,
      'salt': base64.encode(salt),
      'cipher': cipherName,
      'nonce': base64.encode(nonce),
      'ct': base64.encode(box.cipherText),
      'mac': base64.encode(box.mac.bytes),
    };
    return const JsonEncoder.withIndent('  ').convert(env);
  }

  /// Odszyfrowuje [envelopeJson] hasłem [passphrase]. Zwraca tekst jawny (UTF-8).
  /// Rzuca [CryptoException] przy złym haśle lub uszkodzonych danych.
  static Future<String> decrypt(String envelopeJson, String passphrase) async {
    Map<String, dynamic> env;
    try {
      env = jsonDecode(envelopeJson) as Map<String, dynamic>;
    } catch (_) {
      throw const CryptoException('Nieprawidłowy format zaszyfrowanego pliku.');
    }
    try {
      final salt = base64.decode(env['salt'] as String);
      final nonce = base64.decode(env['nonce'] as String);
      final ct = base64.decode(env['ct'] as String);
      final mac = base64.decode(env['mac'] as String);
      final iter = (env['iter'] as int?) ?? iterations;
      final key = await _kdf(iter)
          .deriveKeyFromPassword(password: passphrase, nonce: salt);
      final clear = await _aes.decrypt(
        SecretBox(ct, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on CryptoException {
      rethrow;
    } catch (_) {
      // SecretBoxAuthenticationError (złe hasło) lub błąd base64.
      throw const CryptoException('Błędne hasło lub uszkodzony plik.');
    }
  }
}

class CryptoException implements Exception {
  final String message;
  const CryptoException(this.message);
  @override
  String toString() => message;
}
