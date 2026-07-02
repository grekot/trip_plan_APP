import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_client.dart';
import 'ai_types.dart';

/// Klient Claude API (Anthropic Messages API) przez surowe HTTP — Anthropic
/// nie publikuje oficjalnego SDK dla Darta.
///
/// Format: https://api.anthropic.com/v1/messages
/// - narzędzia: `tools: [{name, description, input_schema}]`
/// - odpowiedź: bloki `content` (thinking / text / tool_use)
/// - wyniki narzędzi: wiadomość user z blokami `tool_result`
/// - bloki thinking odsyłamy w historii bez zmian (wymóg API) — dlatego
///   trzymamy w historii surowe `content` odpowiedzi.
class AnthropicClient implements AiClient {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _timeout = Duration(seconds: 180);

  final String apiKey;
  final String model;

  AnthropicClient({required this.apiKey, required this.model});

  @override
  AiProvider get provider => AiProvider.anthropic;

  @override
  Map<String, dynamic> buildUserMessage(String text) =>
      {'role': 'user', 'content': text};

  @override
  void appendAssistantTurn(List<Map<String, dynamic>> history, AiTurn turn) {
    history.add({'role': 'assistant', 'content': turn.raw});
  }

  @override
  void appendToolRound(
    List<Map<String, dynamic>> history,
    AiTurn turn,
    List<AiToolResult> results,
  ) {
    history.add({'role': 'assistant', 'content': turn.raw});
    // Wszystkie tool_result w JEDNEJ wiadomości user (wymóg API przy
    // równoległych wywołaniach narzędzi).
    history.add({
      'role': 'user',
      'content': [
        for (final r in results)
          {
            'type': 'tool_result',
            'tool_use_id': r.callId,
            'content': r.content,
            if (r.isError) 'is_error': true,
          },
      ],
    });
  }

  @override
  Future<AiTurn> send({
    required String system,
    required List<Map<String, dynamic>> history,
    required List<AiToolDef> tools,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': 16000,
      // Adaptive thinking — model sam decyduje, kiedy i ile myśleć.
      'thinking': {'type': 'adaptive'},
      'system': system,
      'messages': history,
      if (tools.isNotEmpty)
        'tools': [
          for (final t in tools)
            {
              'name': t.name,
              'description': t.description,
              'input_schema': t.schema,
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
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw AiException('Brak połączenia z Claude API: $e');
    }

    if (resp.statusCode != 200) {
      throw AiException(_httpError(resp));
    }

    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final content = (j['content'] as List? ?? []);
    final stopReason = j['stop_reason'] as String?;

    if (stopReason == 'refusal') {
      return AiTurn(
        text: 'Model odmówił wykonania tego polecenia (względy bezpieczeństwa).',
        toolCalls: const [],
        raw: content,
        stopReason: stopReason,
      );
    }

    final textParts = <String>[];
    final calls = <AiToolCall>[];
    for (final block in content) {
      final b = (block as Map).cast<String, dynamic>();
      switch (b['type']) {
        case 'text':
          textParts.add(b['text'] as String? ?? '');
          break;
        case 'tool_use':
          calls.add(AiToolCall(
            id: b['id'] as String,
            name: b['name'] as String,
            args: (b['input'] as Map?)?.cast<String, dynamic>() ?? {},
          ));
          break;
        // Bloki 'thinking' pomijamy w UI — zostają w raw i wracają w historii.
      }
    }

    return AiTurn(
      text: textParts.join('\n').trim(),
      toolCalls: calls,
      raw: content,
      stopReason: stopReason,
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
        return 'Nieprawidłowy klucz API Anthropic. Sprawdź go w ustawieniach asystenta.';
      case 404:
        return 'Nieznany model "$model". Sprawdź nazwę modelu w ustawieniach. $detail';
      case 429:
        return 'Przekroczony limit zapytań Claude API — spróbuj za chwilę.';
      case 529:
        return 'Claude API jest chwilowo przeciążone — spróbuj za chwilę.';
      default:
        return 'Błąd Claude API (${resp.statusCode}): $detail';
    }
  }
}
