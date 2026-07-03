import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trip_models.dart';
import '../providers/journal_providers.dart';
import '../services/geo_service.dart';
import '../widgets/location_button.dart';

bool get _isDesktop {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Dziennik podróży — chronologiczne wpisy „co/gdzie/kiedy", z opcjonalną
/// lokalizacją GPS („Jestem tutaj"). Dane lokalne (Hive), niezależne od planu.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalProvider);
    final scheme = Theme.of(context).colorScheme;
    final dfDay = DateFormat('EEEE, d MMMM yyyy', 'pl_PL');
    final dfTime = DateFormat('HH:mm');

    // Grupowanie po dacie (wpisy są posortowane malejąco po ts).
    final groups = <String, List<JournalEntry>>{};
    for (final e in entries) {
      final key = dfDay.format(e.ts);
      groups.putIfAbsent(key, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dziennik podróży'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: 'Eksportuj dziennik (Markdown)',
              icon: const Icon(Icons.upload_outlined),
              onPressed: () => _export(entries),
            ),
          IconButton(
            tooltip: 'Dodaj wpis (bez lokalizacji)',
            icon: const Icon(Icons.add),
            onPressed: () => _entryDialog(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'journal-here-fab',
        onPressed: _locating ? null : _addHere,
        icon: _locating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location),
        label: Text(_locating ? 'Pobieram GPS…' : 'Jestem tutaj'),
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Brak wpisów.\n\nDodawaj wspomnienia z trasy przyciskiem '
                  '„Jestem tutaj" (z lokalizacją GPS) albo „+" (sam tekst). '
                  'Możesz też poprosić asystenta AI: „zapisz w dzienniku, że…".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final day in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(day.key,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                            fontSize: 14)),
                  ),
                  for (final e in day.value)
                    Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(e.text),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              e.locationName != null
                                  ? '${dfTime.format(e.ts)} · ${e.locationName}'
                                  : dfTime.format(e.ts),
                              style: TextStyle(
                                  fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                            if (e.hasCoords)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: LocationButton(
                                  location: Location(
                                    name: e.locationName ?? 'Miejsce z dziennika',
                                    lat: e.lat!,
                                    lng: e.lng!,
                                  ),
                                  compact: true,
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _entryDialog(entry: e);
                            if (v == 'delete') _confirmDelete(e);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edytuj')),
                            PopupMenuItem(value: 'delete', child: Text('Usuń')),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  /// „Jestem tutaj": GPS → nazwa miejsca → dialog z opisem → zapis.
  Future<void> _addHere() async {
    setState(() => _locating = true);
    CurrentPlace place;
    try {
      place = await GeoService.currentPlace();
    } on GeoException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nie udało się pobrać lokalizacji: $e')));
      }
      return;
    } finally {
      if (mounted) setState(() => _locating = false);
    }
    if (!mounted) return;
    _entryDialog(place: place);
  }

  /// Dialog dodawania/edycji wpisu. [place] = nowy wpis z lokalizacją GPS,
  /// [entry] = edycja istniejącego, żadne = nowy wpis bez lokalizacji.
  void _entryDialog({CurrentPlace? place, JournalEntry? entry}) {
    final textCtl = TextEditingController(text: entry?.text ?? '');
    final placeLabel = place?.name ??
        (place != null
            ? '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}'
            : null);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry != null
            ? 'Edytuj wpis'
            : (place != null ? 'Jestem tutaj' : 'Nowy wpis')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (placeLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(placeLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            TextField(
              controller: textCtl,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'Krótki opis — co się dzieje, jak jest?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj')),
          FilledButton(
            onPressed: () async {
              final text = textCtl.text.trim();
              if (text.isEmpty) return;
              if (entry != null) {
                await ref.read(journalProvider.notifier).updateText(entry.id, text);
              } else {
                await ref.read(journalProvider.notifier).add(
                      text: text,
                      locationName: place?.name,
                      lat: place?.lat,
                      lng: place?.lng,
                    );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(JournalEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć wpis?'),
        content: Text(e.text, maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Usuń')),
        ],
      ),
    );
    if (ok == true) await ref.read(journalProvider.notifier).delete(e.id);
  }

  /// Eksport dziennika do Markdown (desktop: Zapisz jako…, mobile: share).
  Future<void> _export(List<JournalEntry> entries) async {
    final dfDay = DateFormat('EEEE, d MMMM yyyy', 'pl_PL');
    final dfTime = DateFormat('HH:mm');
    final buf = StringBuffer('# Dziennik podróży\n');
    String? lastDay;
    for (final e in entries.reversed) {
      final day = dfDay.format(e.ts);
      if (day != lastDay) {
        buf.write('\n## $day\n\n');
        lastDay = day;
      }
      buf.write('- **${dfTime.format(e.ts)}**');
      if (e.locationName != null) buf.write(' — ${e.locationName}');
      if (e.hasCoords) {
        buf.write(' ([mapa](https://www.google.com/maps/search/?api=1&query=${e.lat},${e.lng}))');
      }
      buf.write(': ${e.text}\n');
    }
    final md = buf.toString();
    final fileName =
        'dziennik-${DateTime.now().millisecondsSinceEpoch}.md';
    try {
      if (_isDesktop) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Zapisz dziennik',
          fileName: fileName,
          bytes: Uint8List.fromList(utf8.encode(md)),
        );
        if (path == null) return;
        final out = File(path);
        if (!await out.exists() || (await out.length()) == 0) {
          await out.writeAsString(md);
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Zapisano: $path')));
        }
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(md);
        await Share.shareXFiles([XFile(file.path)],
            subject: 'Dziennik podróży');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd eksportu: $e')));
      }
    }
  }
}
