import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/plan_providers.dart';
import '../services/passphrase_store.dart';
import '../services/plan_library_service.dart';
import 'qr_scan_screen.dart';

bool get _canScanQr {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// Biblioteka planów: ustawienie hasła, pobieranie zaszyfrowanych planów
/// z chmury (repo trip_plans), wybór aktywnego i usuwanie pobranych.
class PlanLibraryScreen extends ConsumerStatefulWidget {
  const PlanLibraryScreen({super.key});

  @override
  ConsumerState<PlanLibraryScreen> createState() => _PlanLibraryScreenState();
}

class _PlanLibraryScreenState extends ConsumerState<PlanLibraryScreen> {
  List<PlanManifestEntry>? _available;
  bool _loadingCloud = false;
  String? _cloudError;

  Future<void> _fetchCloud() async {
    final pass = await PassphraseStore.get();
    if (pass == null || pass.isEmpty) {
      if (mounted) await _promptPassphrase();
      final p2 = await PassphraseStore.get();
      if (p2 == null || p2.isEmpty) return;
    }
    setState(() {
      _loadingCloud = true;
      _cloudError = null;
    });
    try {
      final pass2 = (await PassphraseStore.get())!;
      final list = await PlanLibraryService.fetchAvailable(pass2);
      if (mounted) setState(() => _available = list);
    } catch (e) {
      if (mounted) setState(() => _cloudError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingCloud = false);
    }
  }

  Future<void> _promptPassphrase() async {
    final ctl = TextEditingController(text: await PassphraseStore.get() ?? '');
    bool obscure = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Hasło planów'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hasło do odszyfrowania planów z chmury. Musi być takie samo, jakim plany były zaszyfrowane.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Hasło',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setD(() => obscure = !obscure),
                  ),
                ),
              ),
              if (_canScanQr) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('albo', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Skanuj kod QR'),
                  onPressed: () async {
                    final scanned = await Navigator.of(ctx).push<String>(
                      MaterialPageRoute(builder: (_) => const QrScanScreen()),
                    );
                    if (scanned != null && scanned.trim().isNotEmpty) {
                      ctl.text = scanned.trim();
                      setD(() {});
                    }
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
          ],
        ),
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      await ref.read(passphraseProvider.notifier).setPassphrase(ctl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPass = ref.watch(passphraseProvider);
    final libA = ref.watch(planLibraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteka planów')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // ---- Hasło ----
          _header(scheme, 'Hasło'),
          ListTile(
            leading: Icon(hasPass ? Icons.lock : Icons.lock_open,
                color: hasPass ? Colors.green : scheme.error),
            title: Text(hasPass ? 'Hasło ustawione' : 'Hasło nieustawione'),
            subtitle: Text(hasPass
                ? 'Tap, aby zmienić'
                : 'Wymagane do pobierania planów z chmury'),
            trailing: hasPass
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Usuń hasło',
                    onPressed: () async {
                      await ref.read(passphraseProvider.notifier).clear();
                    },
                  )
                : null,
            onTap: _promptPassphrase,
          ),

          // ---- Pobrane plany ----
          _header(scheme, 'Pobrane plany (na urządzeniu)'),
          libA.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Błąd: $e', style: TextStyle(color: scheme.error)),
            ),
            data: (lib) {
              if (lib.downloaded.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text('Brak pobranych planów. Pobierz plan z chmury poniżej.'),
                );
              }
              return Column(
                children: lib.downloaded.map((p) {
                  final active = p.id == lib.activeId;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    color: active ? scheme.primaryContainer : null,
                    child: ListTile(
                      leading: Icon(active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: active ? scheme.primary : null),
                      title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: p.subtitle != null ? Text(p.subtitle!) : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Usuń plan',
                        onPressed: () => _confirmDelete(p),
                      ),
                      onTap: active
                          ? null
                          : () => ref.read(planLibraryProvider.notifier).setActive(p.id),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // ---- Chmura ----
          _header(scheme, 'Dostępne w chmurze'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton.tonalIcon(
              onPressed: _loadingCloud ? null : _fetchCloud,
              icon: _loadingCloud
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(_loadingCloud ? 'Sprawdzam…' : 'Sprawdź dostępne plany'),
            ),
          ),
          if (_cloudError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_cloudError!, style: TextStyle(color: scheme.error, fontSize: 13)),
            ),
          if (_available != null)
            ..._available!.map((e) {
              final downloaded = libA.value?.downloaded.any((d) => d.id == e.id) ?? false;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(e.title),
                  subtitle: Text([
                    if (e.subtitle != null) e.subtitle!,
                    if (e.updated != null) 'akt.: ${e.updated}',
                  ].join(' · ')),
                  trailing: downloaded
                      ? TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Aktualizuj'),
                          onPressed: () => _download(e),
                        )
                      : FilledButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Pobierz'),
                          onPressed: () => _download(e),
                        ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _download(PlanManifestEntry e) async {
    final pass = await PassphraseStore.get();
    if (pass == null || pass.isEmpty) {
      await _promptPassphrase();
      return;
    }
    _toast('Pobieram „${e.title}"…');
    try {
      await ref.read(planLibraryProvider.notifier).download(e, pass);
      _toast('Pobrano „${e.title}"');
    } catch (err) {
      _toast('Błąd: $err');
    }
  }

  Future<void> _confirmDelete(DownloadedPlan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć plan?'),
        content: Text('Usunąć „${p.title}" z urządzenia? Notatki i odznaczenia pozostaną w bazie.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(planLibraryProvider.notifier).delete(p.id);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Widget _header(ColorScheme scheme, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Text(t,
            style: TextStyle(
                color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
      );
}
