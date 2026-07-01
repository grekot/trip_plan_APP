import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/trip_loader.dart';
import '../providers/providers.dart';
import '../widgets/update_dialog.dart';

bool get _isDesktop {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final tripA = ref.watch(tripProvider);
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat('EEEE, d MMMM yyyy', 'pl_PL');

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _header(scheme, 'Wyjazd'),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Data startu wyjazdu'),
            subtitle: Text(settings.tripStartDate == null
                ? 'Nie ustawiono'
                : df.format(settings.tripStartDate!)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
                initialDate: settings.tripStartDate ?? now,
              );
              if (picked != null) {
                await ref.read(settingsProvider.notifier).setTripStartDate(picked);
              }
            },
          ),
          if (settings.tripStartDate != null)
            ListTile(
              leading: const Icon(Icons.event_busy),
              title: const Text('Wyczyść datę startu'),
              onTap: () => ref.read(settingsProvider.notifier).clearTripStartDate(),
            ),
          _header(scheme, 'Plan'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Eksportuj plan'),
            subtitle: const Text('Wyślij JSON jako plik (np. na maila, do Drive)'),
            onTap: () => _exportTrip(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Importuj plan z pliku'),
            subtitle: const Text('Wczytaj JSON z dysku telefonu'),
            onTap: () => _importTrip(context, ref),
          ),
          _header(scheme, 'Edycja planu w apce'),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edycja planu (meta, dni, sekcje)'),
            subtitle: const Text('Tytuł, podtytuł, dodawanie/usuwanie dni i sekcji, reorder'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit/meta'),
          ),
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: const Text('Edycja atrakcji extra'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit/extras'),
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Edycja pakowania'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit/packing'),
          ),
          ListTile(
            leading: const Icon(Icons.phone_in_talk_outlined),
            title: const Text('Edycja numerów alarmowych'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit/emergency'),
          ),
          ListTile(
            leading: const Icon(Icons.umbrella_outlined),
            title: const Text('Edycja planów B'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit/contingency'),
          ),
          _header(scheme, 'Postęp'),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Reset postępu (odznaczenia + notatki)'),
            onTap: () => _confirmResetProgress(context, ref),
          ),
          _header(scheme, 'Aktualizacja'),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Sprawdź aktualizację'),
            subtitle: const Text('Pobierz nową wersję z GitHub Releases'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showUpdateDialog(context),
          ),
          _header(scheme, 'O aplikacji'),
          tripA.maybeWhen(
            data: (t) => ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Wersja planu (JSON)'),
              subtitle: Text('v${t.version} — ${t.title}'),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const ListTile(
            leading: Icon(Icons.android),
            title: Text('Aplikacja'),
            subtitle: Text('Słowenia 2026 v1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _header(ColorScheme scheme, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t,
            style: TextStyle(
                color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Future<void> _exportTrip(BuildContext context, WidgetRef ref) async {
    final tripA = ref.read(tripProvider);
    final trip = tripA.value;
    if (trip == null) return;
    try {
      final json = await TripLoader.exportJsonString(trip);
      final fileName = 'slowenia-trip-${DateTime.now().millisecondsSinceEpoch}.json';

      if (_isDesktop) {
        // Na Windows/macOS/Linux używamy natywnego "Zapisz jako…" dialogu.
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Zapisz plan wyjazdu',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: Uint8List.fromList(utf8.encode(json)),
        );
        if (path == null) return; // anulowane
        // Niektóre platformy desktopowe nie przyjmują `bytes` — zapis manualny.
        final out = File(path);
        if (!await out.exists() || (await out.length()) == 0) {
          await out.writeAsString(json);
        }
        if (context.mounted) _toast(context, 'Zapisano: $path');
      } else {
        // Mobile: share intent.
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(json);
        await Share.shareXFiles([XFile(file.path)],
            subject: 'Plan wyjazdu — Słowenia 2026');
      }
    } catch (e) {
      if (context.mounted) _toast(context, 'Błąd eksportu: $e');
    }
  }

  Future<void> _importTrip(BuildContext context, WidgetRef ref) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;
      final text = await File(path).readAsString();
      final imp = await TripLoader.importFromString(text);
      if (!imp.isOk) {
        if (context.mounted) _toast(context, imp.error ?? 'Błąd importu');
        return;
      }
      final oldTrip = ref.read(tripProvider).value;
      if (oldTrip != null) {
        final diff = TripLoader.diff(oldTrip, imp.trip!);
        if (context.mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Importuj plan'),
              content: Text(
                  'Dodanych punktów: ${diff.added}\nUsuniętych: ${diff.removed}\nWspólnych: ${diff.common}\n\nNotatki i odznaczenia zostaną zachowane (kluczowane po ID).'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Importuj')),
              ],
            ),
          );
          if (confirm != true) return;
        }
      }
      await ref.read(tripProvider.notifier).replace(imp.trip!);
      if (context.mounted) _toast(context, 'Plan zaimportowany');
    } catch (e) {
      if (context.mounted) _toast(context, 'Błąd: $e');
    }
  }

  Future<void> _confirmResetProgress(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset postępu?'),
        content: const Text('Wszystkie odznaczenia, notatki i checklist pakowania zostaną wyzerowane.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(progressProvider.notifier).reset();
      await ref.read(notesProvider.notifier).reset();
      await ref.read(packingProvider.notifier).reset();
      if (context.mounted) _toast(context, 'Postęp zresetowany');
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
