// Wspólne typy warstwy AI — neutralne względem dostawcy (Anthropic/DeepSeek).

/// Dostawca usług AI.
enum AiProvider {
  anthropic,
  deepseek,
  gemini;

  static AiProvider fromString(String? s) => AiProvider.values.firstWhere(
        (e) => e.name == s,
        orElse: () => AiProvider.anthropic,
      );

  String get label {
    switch (this) {
      case AiProvider.anthropic:
        return 'Claude (Anthropic)';
      case AiProvider.deepseek:
        return 'DeepSeek';
      case AiProvider.gemini:
        return 'Gemini (Google)';
    }
  }

  /// Domyślny model dla dostawcy.
  String get defaultModel {
    switch (this) {
      case AiProvider.anthropic:
        return 'claude-opus-4-8';
      case AiProvider.deepseek:
        return 'deepseek-chat';
      case AiProvider.gemini:
        return 'gemini-2.5-flash';
    }
  }
}

/// Konfiguracja agenta odczytana z ustawień (provider + model + klucz API).
class AiConfig {
  final AiProvider provider;
  final String model;
  final String apiKey;

  const AiConfig({
    required this.provider,
    required this.model,
    required this.apiKey,
  });

  bool get isValid => apiKey.trim().isNotEmpty;
}

/// Definicja narzędzia (tool) w neutralnym formacie — konwertowana przez
/// klientów do formatu Anthropic (`input_schema`) lub OpenAI (`function`).
class AiToolDef {
  final String name;
  final String description;

  /// JSON Schema parametrów (obiekt `{"type": "object", ...}`).
  final Map<String, dynamic> schema;

  const AiToolDef({
    required this.name,
    required this.description,
    required this.schema,
  });
}

/// Wywołanie narzędzia zażądane przez model.
class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;

  const AiToolCall({required this.id, required this.name, required this.args});
}

/// Wynik wykonania narzędzia (do odesłania modelowi).
class AiToolResult {
  final String callId;
  final String content;
  final bool isError;

  const AiToolResult({
    required this.callId,
    required this.content,
    this.isError = false,
  });
}

/// Jedna tura odpowiedzi modelu: tekst + ewentualne wywołania narzędzi.
/// `raw` przechowuje odpowiedź w natywnym formacie dostawcy — klient używa
/// jej do poprawnego odtworzenia historii (np. bloki thinking u Anthropic,
/// message z tool_calls u DeepSeek).
class AiTurn {
  final String text;
  final List<AiToolCall> toolCalls;
  final dynamic raw;
  final String? stopReason;

  const AiTurn({
    required this.text,
    required this.toolCalls,
    required this.raw,
    this.stopReason,
  });
}

/// Błąd komunikacji z API AI — komunikat gotowy do pokazania użytkownikowi.
class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}
