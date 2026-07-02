import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'ai_types.dart';

/// Ustawienia agenta AI. Klucze API trafiają do secure storage (Keystore /
/// DPAPI — tak samo jak hasło planów), a wybór dostawcy i modelu do Hive
/// (box_settings), bo nie są sekretami.
class AiSettingsStore {
  static const _boxSettings = 'box_settings';
  static const _kProvider = 'aiProvider';
  static const _kModelPrefix = 'aiModel.'; // aiModel.anthropic / aiModel.deepseek

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _apiKeyKey(AiProvider p) => 'ai_api_key_${p.name}';

  static Box get _box => Hive.box(_boxSettings);

  static AiProvider getProvider() =>
      AiProvider.fromString(_box.get(_kProvider) as String?);

  static Future<void> setProvider(AiProvider p) =>
      _box.put(_kProvider, p.name);

  static String getModel(AiProvider p) =>
      (_box.get('$_kModelPrefix${p.name}') as String?) ?? p.defaultModel;

  static Future<void> setModel(AiProvider p, String model) => _box.put(
      '$_kModelPrefix${p.name}',
      model.trim().isEmpty ? p.defaultModel : model.trim());

  static Future<String?> getApiKey(AiProvider p) =>
      _storage.read(key: _apiKeyKey(p));

  static Future<void> setApiKey(AiProvider p, String key) async {
    if (key.trim().isEmpty) {
      await _storage.delete(key: _apiKeyKey(p));
    } else {
      await _storage.write(key: _apiKeyKey(p), value: key.trim());
    }
  }

  /// Pełna konfiguracja dla aktualnie wybranego dostawcy.
  static Future<AiConfig> getConfig() async {
    final p = getProvider();
    return AiConfig(
      provider: p,
      model: getModel(p),
      apiKey: await getApiKey(p) ?? '',
    );
  }
}
