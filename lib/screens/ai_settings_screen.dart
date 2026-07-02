import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_providers.dart';
import '../services/ai/ai_settings_store.dart';
import '../services/ai/ai_types.dart';
import '../services/ai/anthropic_client.dart';
import '../services/ai/deepseek_client.dart';

/// Konfiguracja asystenta AI: dostawca (Claude/DeepSeek), klucz API i model.
/// Klucz trafia do secure storage, dostawca i model do Hive.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late AiProvider _provider;
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _loading = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _provider = AiSettingsStore.getProvider();
    _loadFor(_provider);
  }

  Future<void> _loadFor(AiProvider p) async {
    setState(() => _loading = true);
    final key = await AiSettingsStore.getApiKey(p);
    if (!mounted) return;
    setState(() {
      _keyCtrl.text = key ?? '';
      _modelCtrl.text = AiSettingsStore.getModel(p);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AiSettingsStore.setProvider(_provider);
    await AiSettingsStore.setApiKey(_provider, _keyCtrl.text);
    await AiSettingsStore.setModel(_provider, _modelCtrl.text);
    ref.invalidate(aiConfiguredProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Zapisano ustawienia asystenta')));
    }
  }

  Future<void> _testConnection() async {
    // Zapisz najpierw, żeby test odpowiadał temu, co będzie używane.
    await _save();
    final cfg = await AiSettingsStore.getConfig();
    if (!cfg.isValid) {
      _toast('Podaj klucz API przed testem.');
      return;
    }
    setState(() => _testing = true);
    try {
      final client = switch (cfg.provider) {
        AiProvider.anthropic =>
            AnthropicClient(apiKey: cfg.apiKey, model: cfg.model),
        AiProvider.deepseek =>
            DeepseekClient(apiKey: cfg.apiKey, model: cfg.model),
      };
      final turn = await client.send(
        system: 'Odpowiedz jednym słowem: OK',
        history: [client.buildUserMessage('Test połączenia')],
        tools: const [],
      );
      _toast('Połączenie działa ✓ (${cfg.model}): ${turn.text}');
    } on AiException catch (e) {
      _toast('Test nieudany: ${e.message}');
    } catch (e) {
      _toast('Test nieudany: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Asystent AI — konfiguracja')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Dostawca',
                    style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<AiProvider>(
                  initialValue: _provider,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    for (final p in AiProvider.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (p) {
                    if (p == null) return;
                    setState(() => _provider = p);
                    _loadFor(p);
                  },
                ),
                const SizedBox(height: 20),
                Text('Klucz API',
                    style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _keyCtrl,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: _provider == AiProvider.anthropic
                        ? 'sk-ant-…'
                        : 'sk-…',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _provider == AiProvider.anthropic
                      ? 'Klucz wygenerujesz na platform.claude.com (Console → API Keys).'
                      : 'Klucz wygenerujesz na platform.deepseek.com (API Keys).',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Text('Model',
                    style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelCtrl,
                  autocorrect: false,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: _provider.defaultModel,
                    helperText: 'Domyślnie: ${_provider.defaultModel}',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Zapisz'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: Text(_testing ? 'Testuję…' : 'Zapisz i przetestuj połączenie'),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.info_outline, size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          const Text('Jak to działa',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        const Text(
                          'Asystent modyfikuje aktywny plan podróży na Twoje polecenie '
                          '(np. „dodaj kolację w Bledzie w dniu 3”, „przenieś wąwóz '
                          'Vintgar na rano”). Klucz API jest przechowywany wyłącznie '
                          'na tym urządzeniu (secure storage). Zapytania idą '
                          'bezpośrednio do wybranego dostawcy — wymagany internet.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
