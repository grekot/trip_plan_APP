import 'ai_types.dart';

/// Abstrakcja klienta AI. Każdy dostawca ma inny format wiadomości i tooli,
/// więc klient jest właścicielem historii w formacie natywnym — pętla agenta
/// operuje wyłącznie przez te metody.
abstract class AiClient {
  AiProvider get provider;

  /// Wysyła całą rozmowę (system + historia + narzędzia) i zwraca jedną turę.
  Future<AiTurn> send({
    required String system,
    required List<Map<String, dynamic>> history,
    required List<AiToolDef> tools,
  });

  /// Buduje wiadomość użytkownika w formacie natywnym dostawcy.
  Map<String, dynamic> buildUserMessage(String text);

  /// Dopisuje do historii turę asystenta bez wywołań narzędzi.
  void appendAssistantTurn(List<Map<String, dynamic>> history, AiTurn turn);

  /// Dopisuje do historii turę asystenta z wywołaniami narzędzi oraz ich
  /// wyniki — w formacie wymaganym przez dostawcę.
  void appendToolRound(
    List<Map<String, dynamic>> history,
    AiTurn turn,
    List<AiToolResult> results,
  );
}
