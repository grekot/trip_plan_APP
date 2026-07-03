import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../services/plan_history_service.dart';
import '../services/ai/agent_keepalive.dart';
import '../services/ai/agent_tools.dart';
import '../services/ai/ai_client.dart';
import '../services/ai/ai_settings_store.dart';
import '../services/ai/ai_types.dart';
import '../services/ai/anthropic_client.dart';
import '../services/ai/deepseek_client.dart';
import 'providers.dart';

/// Czy asystent jest skonfigurowany (jest klucz API dla wybranego dostawcy)?
/// Invalidowany po zapisie ustawień AI.
final aiConfiguredProvider = FutureProvider<bool>((ref) async {
  final cfg = await AiSettingsStore.getConfig();
  return cfg.isValid;
});

/// Rodzaj wiadomości w czacie.
enum ChatMsgKind { user, assistant, toolAction, error, info }

class ChatMsg {
  final ChatMsgKind kind;
  final String text;
  const ChatMsg(this.kind, this.text);
}

class AiChatState {
  final List<ChatMsg> messages;
  final bool busy;
  const AiChatState({this.messages = const [], this.busy = false});

  AiChatState copyWith({List<ChatMsg>? messages, bool? busy}) => AiChatState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
      );
}

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) => AiChatNotifier(ref));

/// Notifier czatu z pętlą agentową: wysyła wiadomość → model może wołać
/// narzędzia → wykonujemy je na planie → wyniki wracają do modelu → aż do
/// zwykłej odpowiedzi tekstowej (limit iteracji chroni przed zapętleniem).
class AiChatNotifier extends StateNotifier<AiChatState> {
  static const _maxIterations = 12;

  final Ref _ref;

  /// Historia rozmowy w formacie natywnym dostawcy (zarządzana przez klienta).
  final List<Map<String, dynamic>> _history = [];

  /// Dostawca, którym prowadzono bieżącą rozmowę — zmiana dostawcy wymaga
  /// zresetowania historii (formaty wiadomości są niekompatybilne).
  AiProvider? _historyProvider;

  AiChatNotifier(this._ref) : super(const AiChatState()) {
    _restore();
  }

  void _add(ChatMsgKind kind, String text) {
    state = state.copyWith(messages: [...state.messages, ChatMsg(kind, text)]);
  }

  void clear() {
    _history.clear();
    _historyProvider = null;
    state = const AiChatState();
    _persist();
  }

  // ===== Trwałość rozmowy (Hive) — rozmowa przeżywa ubicie procesu w tle =====

  Box get _box => Hive.box(boxSettings);

  void _persist() {
    _box.put('aiChat.provider', _historyProvider?.name);
    _box.put('aiChat.history', jsonEncode(_history));
    _box.put(
        'aiChat.messages',
        jsonEncode([
          for (final m in state.messages) {'k': m.kind.name, 't': m.text},
        ]));
  }

  void _restore() {
    try {
      final providerName = _box.get('aiChat.provider') as String?;
      final historyJson = _box.get('aiChat.history') as String?;
      final messagesJson = _box.get('aiChat.messages') as String?;
      if (providerName == null || historyJson == null || messagesJson == null) {
        return;
      }
      _historyProvider = AiProvider.fromString(providerName);
      _history
        ..clear()
        ..addAll((jsonDecode(historyJson) as List)
            .map((e) => (e as Map).cast<String, dynamic>()));
      final msgs = (jsonDecode(messagesJson) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .map((m) => ChatMsg(
                ChatMsgKind.values.firstWhere(
                  (k) => k.name == m['k'],
                  orElse: () => ChatMsgKind.info,
                ),
                m['t'] as String? ?? '',
              ))
          .toList();
      if (msgs.isNotEmpty) {
        state = AiChatState(messages: msgs);
      }
    } catch (_) {
      // Uszkodzony stan — zaczynamy od pustej rozmowy.
      _history.clear();
      _historyProvider = null;
    }
  }

  AiClient _buildClient(AiConfig cfg) {
    switch (cfg.provider) {
      case AiProvider.anthropic:
        return AnthropicClient(apiKey: cfg.apiKey, model: cfg.model);
      case AiProvider.deepseek:
        return DeepseekClient(apiKey: cfg.apiKey, model: cfg.model);
    }
  }

  String _systemPrompt() {
    final trip = _ref.read(tripProvider).valueOrNull;
    final tripLine = trip == null
        ? 'Użytkownik nie ma aktywnego planu podróży.'
        : 'Aktywny plan: "${trip.title}"'
            '${trip.subtitle != null ? ' — ${trip.subtitle}' : ''} '
            '(${trip.days.length} dni, ${trip.extras.length} atrakcji extra).';

    // Kontekst czasowy: bieżąca data/godzina + pozycja względem wyjazdu.
    final now = DateTime.now();
    final df = DateFormat('EEEE, d MMMM yyyy', 'pl_PL');
    final tf = DateFormat('HH:mm');
    var timeLine = 'Dziś jest ${df.format(now)}, godzina ${tf.format(now)}.';
    final startDate = _ref.read(settingsProvider).tripStartDate;
    if (startDate != null) {
      timeLine += ' Wyjazd zaczyna się ${df.format(startDate)}.';
      final dayIdx = _ref.read(activeDayIndexProvider);
      if (trip != null && dayIdx != null) {
        if (dayIdx == -1) {
          final left = startDate.difference(DateTime(now.year, now.month, now.day)).inDays;
          timeLine += ' Do wyjazdu zostało $left dni.';
        } else if (dayIdx >= trip.days.length) {
          timeLine += ' Wyjazd już się zakończył.';
        } else {
          final d = trip.days[dayIdx];
          timeLine += ' Dziś jest dzień ${d.number} wyjazdu (id: "${d.id}", „${d.title}”).';
        }
      }
    }
    return 'Jesteś asystentem podróży wbudowanym w aplikację „Plan Podróży”. '
        'Pomagasz przeglądać i modyfikować plan podróży użytkownika za pomocą narzędzi.\n\n'
        'Zasady:\n'
        '- Odpowiadaj po polsku, zwięźle i konkretnie.\n'
        '- Zanim coś zmodyfikujesz, pobierz kontekst narzędziami odczytu '
        '(get_trip_overview, get_day) — identyfikatory day_id/section_id/item_id '
        'bierz WYŁĄCZNIE z wyników narzędzi, nigdy ich nie zgaduj.\n'
        '- Gdy polecenie jest niejednoznaczne (np. nie wiadomo, o który dzień lub '
        'punkt chodzi), zadaj pytanie zamiast zgadywać.\n'
        '- Operacje nieodwracalne (usuwanie dni, sekcji, punktów) wykonuj tylko na '
        'wyraźne polecenie; przy wątpliwościach zaproponuj ukrycie punktu (hidden).\n'
        '- Gdy dodajesz atrakcję extra jako punkt planu dziennego, oznacz ją '
        'potem przez set_extra_used(used=true) — nie usuwaj jej z listy extras, '
        'chyba że użytkownik wyraźnie o to poprosi.\n'
        '- Masz też narzędzia poza planem: prognozę pogody (get_weather_forecast '
        '— przydatna przy proponowaniu planów B), bieżącą pozycję GPS '
        '(get_current_location) i dziennik podróży (get_journal/add_journal_entry). '
        'Gdy użytkownik mówi „jesteśmy tutaj / zapisz to miejsce", pobierz pozycję '
        'GPS i dodaj wpis do dziennika z lokalizacją.\n'
        '- Nie wykonuj zmian, o które użytkownik nie prosił.\n'
        '- Po wykonaniu zmian krótko podsumuj, co zostało zmienione.\n\n'
        '$tripLine\n$timeLine';
  }

  Future<void> send(String text) async {
    final input = text.trim();
    if (input.isEmpty || state.busy) return;

    final cfg = await AiSettingsStore.getConfig();
    if (!cfg.isValid) {
      _add(ChatMsgKind.error,
          'Asystent nie jest skonfigurowany — ustaw klucz API w ustawieniach.');
      return;
    }

    // Zmiana dostawcy w trakcie rozmowy → historia w innym formacie, reset.
    if (_historyProvider != null && _historyProvider != cfg.provider) {
      _history.clear();
      _add(ChatMsgKind.info,
          'Zmieniono dostawcę AI — rozpoczęto nową rozmowę (${cfg.provider.label}).');
    }
    _historyProvider = cfg.provider;

    final client = _buildClient(cfg);
    final executor = AgentToolExecutor(_ref);

    _add(ChatMsgKind.user, input);
    state = state.copyWith(busy: true);
    // Punkt kontrolny: przy błędzie API wycofujemy CAŁĄ nieudaną turę z
    // historii (łącznie z częściowymi rundami narzędzi) — inaczej wisząca
    // wiadomość tool_use bez tool_result psuje kolejne zapytania.
    final checkpoint = _history.length;
    _history.add(client.buildUserMessage(input));

    // Android: powiadomienie foreground service — system nie zamrozi procesu
    // ani nie zerwie połączenia, gdy użytkownik zrzuci apkę w tło.
    await AgentKeepalive.start();

    try {
      var finished = false;
      var snapshotDone = false;
      for (var iter = 0; iter < _maxIterations && !finished; iter++) {
        final turn = await client.send(
          system: _systemPrompt(),
          history: _history,
          tools: agentToolDefs,
        );

        if (turn.toolCalls.isEmpty) {
          client.appendAssistantTurn(_history, turn);
          if (turn.text.isNotEmpty) _add(ChatMsgKind.assistant, turn.text);
          finished = true;
          break;
        }

        // Tekst towarzyszący wywołaniom narzędzi (np. „Sprawdzam plan…”).
        if (turn.text.isNotEmpty) _add(ChatMsgKind.assistant, turn.text);

        final results = <AiToolResult>[];
        for (final call in turn.toolCalls) {
          // Przed PIERWSZĄ modyfikacją w tej turze zapisz snapshot planu do
          // historii zmian — żeby dało się cofnąć całą akcję agenta.
          if (!snapshotDone && !readOnlyAgentTools.contains(call.name)) {
            final trip = _ref.read(tripProvider).valueOrNull;
            if (trip != null) {
              final shortLabel =
                  input.length > 80 ? '${input.substring(0, 80)}…' : input;
              await PlanHistoryService.snapshot(trip, 'AI: $shortLabel');
            }
            snapshotDone = true;
          }
          final outcome = await executor.execute(call.name, call.args);
          if (outcome.label != null) {
            _add(ChatMsgKind.toolAction, outcome.label!);
          }
          results.add(AiToolResult(
            callId: call.id,
            content: outcome.content,
            isError: outcome.isError,
          ));
        }
        client.appendToolRound(_history, turn, results);
      }

      if (!finished) {
        _add(ChatMsgKind.error,
            'Przerwano — osiągnięto limit kroków agenta ($_maxIterations). '
            'Spróbuj rozbić polecenie na mniejsze.');
      }
    } on AiException catch (e) {
      _add(ChatMsgKind.error, e.message);
      _history.removeRange(checkpoint, _history.length);
    } catch (e) {
      _add(ChatMsgKind.error, 'Nieoczekiwany błąd: $e');
    } finally {
      await AgentKeepalive.stop();
      state = state.copyWith(busy: false);
      _persist();
    }
  }
}
