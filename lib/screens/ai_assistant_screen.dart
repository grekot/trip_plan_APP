import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/ai_providers.dart';

/// Czat z asystentem AI modyfikującym plan podróży.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Rozpoznawanie mowy (pl_PL) — tylko Android/iOS.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  bool get _canUseVoice => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void dispose() {
    if (_listening) _speech.stop();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          // 'done' / 'notListening' — silnik sam kończy po pauzie w mówieniu.
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() => _listening = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Rozpoznawanie mowy: ${e.errorMsg}')));
          }
        },
      );
      if (!_speechReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Rozpoznawanie mowy niedostępne — sprawdź uprawnienie do mikrofonu.')));
        }
        return;
      }
    }
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'pl_PL',
      listenOptions: stt.SpeechListenOptions(partialResults: true),
      onResult: (result) {
        // Podgląd na żywo w polu tekstowym; wysyłka dopiero po zatwierdzeniu
        // przez użytkownika (przycisk wyślij) — bez auto-wysyłania.
        setState(() => _inputCtrl.text = result.recognizedWords);
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    ref.read(aiChatProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(aiChatProvider);
    final configured = ref.watch(aiConfiguredProvider);
    final scheme = Theme.of(context).colorScheme;

    // Auto-przewijanie po każdej zmianie listy wiadomości.
    ref.listen(aiChatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asystent AI'),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: 'Nowa rozmowa',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => ref.read(aiChatProvider.notifier).clear(),
            ),
          IconButton(
            tooltip: 'Konfiguracja asystenta',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/settings/ai'),
          ),
        ],
      ),
      body: configured.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (isConfigured) {
          if (!isConfigured) return _notConfigured(context, scheme);
          return Column(
            children: [
              Expanded(
                child: chat.messages.isEmpty
                    ? _emptyHint(scheme)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: chat.messages.length,
                        itemBuilder: (ctx, i) => _bubble(chat.messages[i], scheme),
                      ),
              ),
              if (chat.busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('Asystent pracuje…',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          enabled: !chat.busy,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Np. „dodaj kolację w dniu 3”…',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      if (_canUseVoice) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: _listening
                              ? 'Zatrzymaj nagrywanie'
                              : 'Podyktuj polecenie',
                          onPressed: chat.busy ? null : _toggleListen,
                          icon: Icon(
                            _listening ? Icons.mic : Icons.mic_none,
                            color: _listening
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      IconButton.filled(
                        onPressed: chat.busy ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _notConfigured(BuildContext context, ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, size: 56, color: scheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Asystent AI nie jest jeszcze skonfigurowany.\n'
                'Wybierz dostawcę (Claude lub DeepSeek) i podaj klucz API.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/settings/ai'),
                icon: const Icon(Icons.tune),
                label: const Text('Skonfiguruj asystenta'),
              ),
            ],
          ),
        ),
      );

  Widget _emptyHint(ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, size: 48, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                'Powiedz, co zmienić w planie, np.:\n\n'
                '„Co mamy zaplanowane w dniu 2?”\n'
                '„Dodaj przerwę na lody po wąwozie Vintgar”\n'
                '„Przenieś baseny na popołudnie dnia 4”\n'
                '„Dodaj kremy z filtrem do listy pakowania”',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _bubble(ChatMsg m, ColorScheme scheme) {
    switch (m.kind) {
      case ChatMsgKind.user:
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(top: 6, bottom: 6, left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(m.text,
                style: TextStyle(color: scheme.onPrimaryContainer)),
          ),
        );
      case ChatMsgKind.assistant:
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(top: 6, bottom: 6, right: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(m.text),
          ),
        );
      case ChatMsgKind.toolAction:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Icons.build_circle_outlined,
                  size: 16, color: scheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(m.text,
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: scheme.tertiary)),
              ),
            ],
          ),
        );
      case ChatMsgKind.error:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(m.text,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13)),
        );
      case ChatMsgKind.info:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(m.text,
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        );
    }
  }
}
