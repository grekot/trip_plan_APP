import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_client.dart';
import 'ai_types.dart';

/// Wspólny klient dla dostawców z API zgodnym z formatem OpenAI
/// (chat/completions + function calling): DeepSeek i Gemini.
///
/// - narzędzia: `tools: [{type: "function", function: {...}}]`
/// - odpowiedź: `choices[0].message` z opcjonalnym `tool_calls`
/// - wyniki narzędzi: osobne wiadomości `role: "tool"` z `tool_call_id`
class OpenAiCompatClient implements AiClient {
  static const _timeout = Duration(seconds: 180);

  @override
  final AiProvider provider;
  final String endpoint;
  final String providerLabel;
  final String apiKey;
  final String model;

  OpenAiCompatClient.deepseek({required this.apiKey, required this.model})
      : provider = AiProvider.deepseek,
        endpoint = 'https://api.deepseek.com/chat/completions',
        providerLabel = 'DeepSeek';

  /// Gemini przez warstwę zgodności OpenAI (generativelanguage.googleapis.com).
  OpenAiCompatClient.gemini({required this.apiKey, required this.model})
      : provider = AiProvider.gemini,
        endpoint =
            'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
        providerLabel = 'Gemini';

  @override
  Map<String, dynamic> buildUserMessage(String text) =>
      {'role': 'user', 'content': text};

  @override
  void appendAssistantTurn(List<Map<String, dynamic>> history, AiTurn turn) {
    history.add((turn.raw as Map).cast<String, dynamic>());
  }

  @override
  void appendToolRound(
    List<Map<String, dynamic>> history,
    AiTurn turn,
    List<AiToolResult> results,
  ) {
    // Wiadomość asystenta z tool_calls musi wrócić do historii w oryginale.
    history.add((turn.raw as Map).cast<String, dynamic>());
    for (final r in results) {
      history.add({
        'role': 'tool',
        'tool_call_id': r.callId,
        'content': r.isError ? 'BŁĄD: ${r.content}' : r.content,
      });
    }
  }

  @override
  Future<AiTurn> send({
    required String system,
    required List<Map<String, dynamic>> history,
    required List<AiToolDef> tools,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        ...history,
      ],
      if (tools.isNotEmpty)
        'tools': [
          for (final t in tools)
            {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.schema,
              },
            },
        ],
    };

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw AiException('Brak połączenia z $providerLabel API: $e');
    }

    if (resp.statusCode != 200) {
      throw AiException(_httpError(resp));
    }

    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final choices = j['choices'] as List? ?? [];
    if (choices.isEmpty) {
      throw AiException('$providerLabel zwrócił pustą odpowiedź.');
    }
    final choice = (choices.first as Map).cast<String, dynamic>();
    final message = (choice['message'] as Map).cast<String, dynamic>();
    final finishReason = choice['finish_reason'] as String?;

    final calls = <AiToolCall>[];
    for (final tc in (message['tool_calls'] as List? ?? [])) {
      final m = (tc as Map).cast<String, dynamic>();
      final fn = (m['function'] as Map).cast<String, dynamic>();
      Map<String, dynamic> args = {};
      try {
        final parsed = jsonDecode(fn['arguments'] as String? ?? '{}');
        if (parsed is Map) args = parsed.cast<String, dynamic>();
      } catch (_) {
        // Nieparsowalne argumenty — przekażemy pusty obiekt, executor zgłosi błąd.
      }
      calls.add(AiToolCall(
        id: m['id'] as String? ?? '',
        name: fn['name'] as String? ?? '',
        args: args,
      ));
    }

    return AiTurn(
      text: (message['content'] as String? ?? '').trim(),
      toolCalls: calls,
      raw: message,
      stopReason: finishReason,
    );
  }

  String _httpError(http.Response resp) {
    String detail = '';
    try {
      final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final err = j['error'];
      if (err is Map) detail = (err['message'] as String?) ?? '';
    } catch (_) {}
    switch (resp.statusCode) {
      case 400:
        return detail.toLowerCase().contains('api key')
            ? 'Nieprawidłowy klucz API $providerLabel. Sprawdź go w ustawieniach asystenta.'
            : 'Błąd $providerLabel API (400): $detail';
      case 401:
      case 403:
        return 'Nieprawidłowy klucz API $providerLabel. Sprawdź go w ustawieniach asystenta.';
      case 402:
        return 'Brak środków na koncie $providerLabel — doładuj konto.';
      case 404:
        return 'Nieznany model "$model" u dostawcy $providerLabel. $detail';
      case 429:
        return 'Przekroczony limit zapytań $providerLabel — spróbuj za chwilę.';
      default:
        return 'Błąd $providerLabel API (${resp.statusCode}): $detail';
    }
  }
}
