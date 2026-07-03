import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

const String boxJournal = 'box_journal';

/// Wpis dziennika podróży — osobisty zapis „co/gdzie/kiedy" w trasie.
/// Dziennik żyje w Hive (lokalnie, poza trip.json) — to dane z podróży,
/// nie część współdzielonego planu.
class JournalEntry {
  final String id;
  final DateTime ts;
  final String text;
  final String? locationName;
  final double? lat;
  final double? lng;

  const JournalEntry({
    required this.id,
    required this.ts,
    required this.text,
    this.locationName,
    this.lat,
    this.lng,
  });

  bool get hasCoords => lat != null && lng != null;

  Map<String, dynamic> toMap() => {
        'ts': ts.toIso8601String(),
        'text': text,
        if (locationName != null) 'locationName': locationName,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  static JournalEntry fromMap(String id, Map m) => JournalEntry(
        id: id,
        ts: DateTime.tryParse(m['ts'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        text: m['text'] as String? ?? '',
        locationName: m['locationName'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );

  JournalEntry copyWith({String? text}) => JournalEntry(
        id: id,
        ts: ts,
        text: text ?? this.text,
        locationName: locationName,
        lat: lat,
        lng: lng,
      );
}

final journalProvider =
    StateNotifierProvider<JournalNotifier, List<JournalEntry>>(
        (ref) => JournalNotifier());

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  JournalNotifier() : super(const []) {
    _load();
  }

  final Box _box = Hive.box(boxJournal);

  void _load() {
    final entries = <JournalEntry>[];
    for (final k in _box.keys) {
      final v = _box.get(k);
      if (v is Map) entries.add(JournalEntry.fromMap(k.toString(), v));
    }
    entries.sort((a, b) => b.ts.compareTo(a.ts)); // najnowsze pierwsze
    state = entries;
  }

  Future<JournalEntry> add({
    required String text,
    String? locationName,
    double? lat,
    double? lng,
    DateTime? ts,
  }) async {
    final entry = JournalEntry(
      id: const Uuid().v4(),
      ts: ts ?? DateTime.now(),
      text: text,
      locationName: locationName,
      lat: lat,
      lng: lng,
    );
    await _box.put(entry.id, entry.toMap());
    state = [entry, ...state]..sort((a, b) => b.ts.compareTo(a.ts));
    return entry;
  }

  Future<void> updateText(String id, String text) async {
    final idx = state.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final updated = state[idx].copyWith(text: text);
    await _box.put(id, updated.toMap());
    final list = [...state];
    list[idx] = updated;
    state = list;
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    state = state.where((e) => e.id != id).toList();
  }
}
