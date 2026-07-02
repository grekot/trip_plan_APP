import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_types.dart';

/// Katalog modeli: wbudowana lista sprawdzonych modeli per dostawca +
/// pobieranie aktualnej listy z API dostawcy (wymaga klucza).
class ModelCatalog {
  /// Sprawdzone modele z krótkim opisem (etykieta w dropdownie).
  static const Map<AiProvider, Map<String, String>> curated = {
    AiProvider.anthropic: {
      'claude-opus-4-8': 'najlepszy (domyślny)',
      'claude-sonnet-4-6': 'szybszy i tańszy',
      'claude-haiku-4-5': 'najtańszy',
    },
    AiProvider.deepseek: {
      'deepseek-chat': 'zalecany (domyślny)',
      'deepseek-reasoner': 'rozumujący (wolniejszy)',
    },
  };

  /// Pobiera listę ID modeli z API dostawcy.
  static Future<List<String>> fetch(AiProvider provider, String apiKey) async {
    final Uri uri;
    final Map<String, String> headers;
    switch (provider) {
      case AiProvider.anthropic:
        uri = Uri.parse('https://api.anthropic.com/v1/models?limit=100');
        headers = {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        };
        break;
      case AiProvider.deepseek:
        uri = Uri.parse('https://api.deepseek.com/models');
        headers = {'authorization': 'Bearer $apiKey'};
        break;
    }

    http.Response resp;
    try {
      resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AiException('Nie udało się pobrać listy modeli: $e');
    }
    if (resp.statusCode == 401) {
      throw const AiException('Nieprawidłowy klucz API — nie można pobrać listy modeli.');
    }
    if (resp.statusCode != 200) {
      throw AiException('Błąd pobierania listy modeli (${resp.statusCode}).');
    }

    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final data = (j['data'] as List? ?? []);
    final ids = <String>[
      for (final m in data)
        if ((m as Map)['id'] is String) m['id'] as String,
    ];
    if (ids.isEmpty) {
      throw const AiException('Dostawca zwrócił pustą listę modeli.');
    }
    ids.sort();
    return ids;
  }
}
