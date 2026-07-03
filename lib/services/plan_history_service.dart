import 'dart:convert';
import 'dart:io';
import '../data/trip_loader.dart';
import '../models/trip_models.dart';

/// Jeden zapisany stan planu (snapshot) w historii zmian.
class PlanSnapshot {
  final File file;
  final String label;
  final DateTime savedAt;

  PlanSnapshot({required this.file, required this.label, required this.savedAt});
}

/// Historia zmian planu — snapshoty całego JSON-a przed „ryzykownymi"
/// operacjami (modyfikacje przez agenta AI, import z pliku, przywrócenie).
/// Snapshoty leżą w `documents/plans/history/<planId>/<millis>.json` jako
/// koperta {label, savedAt, trip}. Trzymamy ostatnich [maxSnapshots] wpisów
/// per plan; pliki są małe (dziesiątki–setki KB), więc to pomijalny koszt.
class PlanHistoryService {
  static const int maxSnapshots = 20;

  static Future<Directory?> _historyDir({bool create = true}) async {
    final planId = TripLoader.activePlanId();
    if (planId == null) return null;
    final plans = await TripLoader.plansDir();
    final d = Directory('${plans.path}/history/$planId');
    if (create && !await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Zapisuje snapshot bieżącego stanu planu z etykietą (np. treść polecenia
  /// dla agenta AI). Przycina historię do [maxSnapshots] wpisów.
  static Future<void> snapshot(Trip trip, String label) async {
    final dir = await _historyDir();
    if (dir == null) return;
    final now = DateTime.now();
    final file = File('${dir.path}/${now.millisecondsSinceEpoch}.json');
    final envelope = {
      'label': label,
      'savedAt': now.toIso8601String(),
      'trip': trip.toJson(),
    };
    await file.writeAsString(jsonEncode(envelope));
    await _prune(dir);
  }

  static Future<void> _prune(Directory dir) async {
    final files = await _snapshotFiles(dir);
    if (files.length <= maxSnapshots) return;
    // Posortowane malejąco po nazwie (= timestamp) — usuwamy najstarsze.
    for (final f in files.skip(maxSnapshots)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static Future<List<File>> _snapshotFiles(Directory dir) async {
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.json')) files.add(e);
    }
    // Nazwa pliku to millisecondsSinceEpoch — sort malejąco = od najnowszego.
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Lista snapshotów aktywnego planu, od najnowszego.
  static Future<List<PlanSnapshot>> list() async {
    final dir = await _historyDir(create: false);
    if (dir == null || !await dir.exists()) return [];
    final result = <PlanSnapshot>[];
    for (final f in await _snapshotFiles(dir)) {
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        result.add(PlanSnapshot(
          file: f,
          label: j['label'] as String? ?? '(bez opisu)',
          savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ));
      } catch (_) {
        // Uszkodzony snapshot pomijamy.
      }
    }
    return result;
  }

  /// Odczytuje plan ze snapshotu (do przywrócenia przez tripProvider.replace).
  static Future<Trip> readTrip(PlanSnapshot s) async {
    final j = jsonDecode(await s.file.readAsString()) as Map<String, dynamic>;
    return Trip.fromJson((j['trip'] as Map).cast<String, dynamic>());
  }

  static Future<void> delete(PlanSnapshot s) async {
    try {
      await s.file.delete();
    } catch (_) {}
  }
}
