import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_client.dart';
import 'ai_types.dart';

/// Klient DeepSeek — API zgodne z formatem OpenAI (chat/completions,
/// function calling). https://api-docs.deepseek.com
///
/// - narzędzia: `tools: [{type: "function", function: {...}}]`
/// - odpowiedź: `choices[0].message` z opcjonalnym `tool_calls`
/// - wyniki narzędzi: osobne wiadomości `role: "tool"` z `tool_call_id`
class DeepseekClient implements AiClient {
  static const _endpoint = 'https://api.deepseek.com/chat/completions';
  static const _timeout = Duration(seconds: 180);

  final String apiKey;
  final String model;

  DeepseekClient({required this.apiKey, required this.model});

  @override
  AiProvider get provider => AiProvider.deepseek;

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
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw AiException('Brak połączenia z DeepSeek API: $e');
    }

    if (resp.statusCode != 200) {
      throw AiException(_httpError(resp));
    }

    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final choices = j['choices'] as List? ?? [];
    if (choices.isEmpty) {
      throw const AiException('DeepSeek zwrócił pustą odpowiedź.');
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
      detail = ((j['error'] as Map?)?['message'] as String?) ?? '';
    } catch (_) {}
    switch (resp.statusCode) {
      case 401:
        return 'Nieprawidłowy klucz API DeepSeek. Sprawdź go w ustawieniach asystenta.';
      case 402:
        return 'Brak środków na koncie DeepSeek (doładuj konto na platform.deepseek.com).';
      case 429:
        return 'Przekroczony limit zapytań DeepSeek — spróbuj za chwilę.';
      default:
        return 'Błąd DeepSeek API (${resp.statusCode}): $detail';
    }
  }
}
