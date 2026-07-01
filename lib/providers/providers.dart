import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../data/trip_loader.dart';
import '../models/trip_models.dart';
import '../models/enums.dart';

const String boxProgress = 'box_progress';
const String boxNotes = 'box_notes';
const String boxPacking = 'box_packing';
const String boxSettings = 'box_settings';

final tripProvider =
    StateNotifierProvider<TripNotifier, AsyncValue<Trip>>((ref) => TripNotifier());

class TripNotifier extends StateNotifier<AsyncValue<Trip>> {
  TripNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await TripLoader.load();
      state = AsyncValue.data(r.trip);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _commit(Trip t) async {
    state = AsyncValue.data(t);
    await TripLoader.save(t);
  }

  Trip? get current => state.value;

  Future<void> replace(Trip t) async => _commit(t);

  /// Przeładowuje aktywny plan z dysku (po zmianie aktywnego planu, pobraniu
  /// nowego z chmury albo usunięciu bieżącego).
  Future<void> reload() async {
    state = const AsyncValue.loading();
    await _load();
  }

  // ===== Helpers to build a new Trip with one field changed =====
  Trip _tripWith({
    String? title,
    String? subtitle,
    String? summary,
    int? version,
    List<Day>? days,
    List<ExtraAttraction>? extras,
    List<PackingItem>? packing,
    List<EmergencyContact>? emergency,
    List<Contingency>? contingency,
    Map<String, dynamic>? practical,
  }) {
    final t = state.value!;
    return Trip(
      version: version ?? t.version,
      title: title ?? t.title,
      subtitle: subtitle ?? t.subtitle,
      summary: summary ?? t.summary,
      days: days ?? t.days,
      extras: extras ?? t.extras,
      packing: packing ?? t.packing,
      emergency: emergency ?? t.emergency,
      contingency: contingency ?? t.contingency,
      practical: practical ?? t.practical,
    );
  }

  Day _dayWith(Day d, {
    String? id, int? number, String? title, String? summary,
    List<Section>? sections, List<Item>? alternatives,
  }) => Day(
    id: id ?? d.id,
    number: number ?? d.number,
    title: title ?? d.title,
    summary: summary ?? d.summary,
    sections: sections ?? d.sections,
    alternatives: alternatives ?? d.alternatives,
  );

  Section _sectionWith(Section s, {
    String? id, String? title, String? timeWindow, List<Item>? items,
  }) => Section(
    id: id ?? s.id,
    title: title ?? s.title,
    timeWindow: timeWindow ?? s.timeWindow,
    items: items ?? s.items,
  );

  // ===== Meta edit =====
  Future<void> updateMeta({String? title, String? subtitle, String? summary, int? version}) async {
    if (state.value == null) return;
    await _commit(_tripWith(title: title, subtitle: subtitle, summary: summary, version: version));
  }

  // ===== Day operations =====
  Future<void> updateDay(int dayIdx, {String? id, int? number, String? title, String? summary}) async {
    final t = state.value;
    if (t == null) return;
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(t.days[dayIdx], id: id, number: number, title: title, summary: summary);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> addDay({String? title, int? number}) async {
    final t = state.value;
    if (t == null) return;
    final n = number ?? (t.days.length + 1);
    final newDay = Day(
      id: 'd$n',
      number: n,
      title: title ?? 'Dzień $n',
      summary: '',
      sections: [],
      alternatives: [],
    );
    await _commit(_tripWith(days: [...t.days, newDay]));
  }

  Future<void> deleteDay(int dayIdx) async {
    final t = state.value;
    if (t == null) return;
    final newDays = [...t.days]..removeAt(dayIdx);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> reorderDays(int oldIdx, int newIdx) async {
    final t = state.value;
    if (t == null) return;
    final newDays = [...t.days];
    if (newIdx > oldIdx) newIdx--;
    final moved = newDays.removeAt(oldIdx);
    newDays.insert(newIdx, moved);
    await _commit(_tripWith(days: newDays));
  }

  // ===== Section operations =====
  Future<void> addSection(int dayIdx, {String? title, String? timeWindow}) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final n = day.sections.length + 1;
    final newSection = Section(
      id: '${day.id}.sec$n',
      title: title ?? 'Sekcja $n',
      timeWindow: timeWindow,
      items: [],
    );
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, sections: [...day.sections, newSection]);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> updateSection(int dayIdx, int secIdx, {String? id, String? title, String? timeWindow}) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final newSecs = [...day.sections];
    newSecs[secIdx] = _sectionWith(day.sections[secIdx], id: id, title: title, timeWindow: timeWindow);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, sections: newSecs);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> deleteSection(int dayIdx, int secIdx) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final newSecs = [...day.sections]..removeAt(secIdx);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, sections: newSecs);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> reorderSections(int dayIdx, int oldIdx, int newIdx) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final newSecs = [...day.sections];
    if (newIdx > oldIdx) newIdx--;
    final moved = newSecs.removeAt(oldIdx);
    newSecs.insert(newIdx, moved);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, sections: newSecs);
    await _commit(_tripWith(days: newDays));
  }

  // ===== Item operations =====
  Future<void> updateItem(int dayIdx, int secIdx, int itemIdx, Item updated) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final sec = day.sections[secIdx];
    final newItems = [...sec.items];
    newItems[itemIdx] = updated;
    final newSecs = [...day.sections];
    newSecs[secIdx] = _sectionWith(sec, items: newItems);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, sections: newSecs);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> addItem(int dayIdx, int secIdx, Item item) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final sec = day.sections[secIdx];
    final newSecs = [...day.sections];
    newSecs[secIdx] = _sectionWith(sec, items: [...sec.items, item]);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, sections: newSecs);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> deleteItem(int dayIdx, int secIdx, int itemIdx) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final sec = day.sections[secIdx];
    final newItems = [...sec.items]..removeAt(itemIdx);
    final newSecs = [...day.sections];
    newSecs[secIdx] = _sectionWith(sec, items: newItems);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, sections: newSecs);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> reorderItems(int dayIdx, int secIdx, int oldIdx, int newIdx) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final sec = day.sections[secIdx];
    final newItems = [...sec.items];
    if (newIdx > oldIdx) newIdx--;
    final moved = newItems.removeAt(oldIdx);
    newItems.insert(newIdx, moved);
    final newSecs = [...day.sections];
    newSecs[secIdx] = _sectionWith(sec, items: newItems);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, sections: newSecs);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> duplicateItem(int dayIdx, int secIdx, int itemIdx) async {
    final t = state.value;
    if (t == null) return;
    final orig = t.days[dayIdx].sections[secIdx].items[itemIdx];
    final copy = orig.copyWith(
      title: '${orig.title} (kopia)',
    );
    // generate new id
    final copy2 = Item(
      id: 'custom.${const Uuid().v4()}',
      title: copy.title,
      description: copy.description,
      type: copy.type,
      location: copy.location,
      locations: copy.locations,
      costEur: copy.costEur,
      duration: copy.duration,
      tips: copy.tips,
      hidden: false,
      userAdded: true,
    );
    final sec = t.days[dayIdx].sections[secIdx];
    final newItems = [...sec.items];
    newItems.insert(itemIdx + 1, copy2);
    final newSecs = [...t.days[dayIdx].sections];
    newSecs[secIdx] = _sectionWith(sec, items: newItems);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(t.days[dayIdx], sections: newSecs);
    await _commit(_tripWith(days: newDays));
  }

  // ===== Hidden toggle (existing API) =====
  Future<void> toggleHidden(String itemId) async {
    final t = state.value;
    if (t == null) return;
    final newDays = t.days.map((d) {
      final newSections = d.sections.map((s) {
        final newItems = s.items.map((i) {
          if (i.id == itemId) return i.copyWith(hidden: !i.hidden);
          return i;
        }).toList();
        return _sectionWith(s, items: newItems);
      }).toList();
      return _dayWith(d, sections: newSections);
    }).toList();
    await _commit(_tripWith(days: newDays));
  }

  // ===== Custom item (existing API, kept for backward compat) =====
  Future<String> addCustomItem({
    required String dayId,
    required String sectionId,
    required String title,
    String? description,
    ItemType type = ItemType.sightseeing,
  }) async {
    final t = state.value;
    if (t == null) return '';
    final id = 'custom.${const Uuid().v4()}';
    final newItem = Item(
      id: id,
      title: title,
      description: description,
      type: type,
      userAdded: true,
    );
    final newDays = t.days.map((d) {
      if (d.id != dayId) return d;
      final newSections = d.sections.map((s) {
        if (s.id != sectionId) return s;
        return _sectionWith(s, items: [...s.items, newItem]);
      }).toList();
      return _dayWith(d, sections: newSections);
    }).toList();
    await _commit(_tripWith(days: newDays));
    return id;
  }

  Future<void> deleteCustomItem(String itemId) async {
    final t = state.value;
    if (t == null) return;
    final newDays = t.days.map((d) {
      final newSections = d.sections.map((s) {
        return _sectionWith(s, items: s.items.where((i) => i.id != itemId || !i.userAdded).toList());
      }).toList();
      return _dayWith(d, sections: newSections);
    }).toList();
    await _commit(_tripWith(days: newDays));
  }

  // ===== Extras =====
  Future<void> updateExtra(int idx, ExtraAttraction updated) async {
    final t = state.value;
    if (t == null) return;
    final newExtras = [...t.extras];
    newExtras[idx] = updated;
    await _commit(_tripWith(extras: newExtras));
  }

  Future<void> addExtra(ExtraAttraction extra) async {
    final t = state.value;
    if (t == null) return;
    await _commit(_tripWith(extras: [...t.extras, extra]));
  }

  Future<void> deleteExtra(int idx) async {
    final t = state.value;
    if (t == null) return;
    final newExtras = [...t.extras]..removeAt(idx);
    await _commit(_tripWith(extras: newExtras));
  }

  // ===== Packing =====
  Future<void> updatePackingItem(int idx, PackingItem updated) async {
    final t = state.value;
    if (t == null) return;
    final newPacking = [...t.packing];
    newPacking[idx] = updated;
    await _commit(_tripWith(packing: newPacking));
  }

  Future<void> addPackingItem(PackingItem item) async {
    final t = state.value;
    if (t == null) return;
    await _commit(_tripWith(packing: [...t.packing, item]));
  }

  Future<void> deletePackingItem(int idx) async {
    final t = state.value;
    if (t == null) return;
    final newPacking = [...t.packing]..removeAt(idx);
    await _commit(_tripWith(packing: newPacking));
  }

  // ===== Emergency =====
  Future<void> updateEmergency(int idx, EmergencyContact updated) async {
    final t = state.value;
    if (t == null) return;
    final newE = [...t.emergency];
    newE[idx] = updated;
    await _commit(_tripWith(emergency: newE));
  }

  Future<void> addEmergency(EmergencyContact e) async {
    final t = state.value;
    if (t == null) return;
    await _commit(_tripWith(emergency: [...t.emergency, e]));
  }

  Future<void> deleteEmergency(int idx) async {
    final t = state.value;
    if (t == null) return;
    final newE = [...t.emergency]..removeAt(idx);
    await _commit(_tripWith(emergency: newE));
  }

  // ===== Contingency =====
  Future<void> updateContingency(int idx, Contingency updated) async {
    final t = state.value;
    if (t == null) return;
    final newC = [...t.contingency];
    newC[idx] = updated;
    await _commit(_tripWith(contingency: newC));
  }

  Future<void> addContingency(Contingency c) async {
    final t = state.value;
    if (t == null) return;
    await _commit(_tripWith(contingency: [...t.contingency, c]));
  }

  Future<void> deleteContingency(int idx) async {
    final t = state.value;
    if (t == null) return;
    final newC = [...t.contingency]..removeAt(idx);
    await _commit(_tripWith(contingency: newC));
  }

  // ===== Alternatives (in days) =====
  Future<void> updateAlternative(int dayIdx, int altIdx, Item updated) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final newAlts = [...day.alternatives];
    newAlts[altIdx] = updated;
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, alternatives: newAlts);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> addAlternative(int dayIdx, Item alt) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, alternatives: [...day.alternatives, alt]);
    await _commit(_tripWith(days: newDays));
  }

  Future<void> deleteAlternative(int dayIdx, int altIdx) async {
    final t = state.value;
    if (t == null) return;
    final day = t.days[dayIdx];
    final newAlts = [...day.alternatives]..removeAt(altIdx);
    final newDays = [...t.days];
    newDays[dayIdx] = _dayWith(day, alternatives: newAlts);
    await _commit(_tripWith(days: newDays));
  }
}

final progressProvider =
    StateNotifierProvider<ProgressNotifier, Map<String, bool>>((ref) => ProgressNotifier());

class ProgressNotifier extends StateNotifier<Map<String, bool>> {
  ProgressNotifier() : super({}) {
    _load();
  }
  final Box _box = Hive.box(boxProgress);

  void _load() {
    final m = <String, bool>{};
    for (final k in _box.keys) {
      m[k.toString()] = _box.get(k) == true;
    }
    state = m;
  }

  bool isChecked(String id) => state[id] ?? false;

  Future<void> toggle(String id) async {
    final v = !(state[id] ?? false);
    await _box.put(id, v);
    state = {...state, id: v};
  }

  Future<void> reset() async {
    await _box.clear();
    state = {};
  }
}

final notesProvider =
    StateNotifierProvider<NotesNotifier, Map<String, String>>((ref) => NotesNotifier());

class NotesNotifier extends StateNotifier<Map<String, String>> {
  NotesNotifier() : super({}) {
    _load();
  }
  final Box _box = Hive.box(boxNotes);

  void _load() {
    final m = <String, String>{};
    for (final k in _box.keys) {
      final v = _box.get(k);
      if (v is String && v.isNotEmpty) m[k.toString()] = v;
    }
    state = m;
  }

  String noteFor(String id) => state[id] ?? '';

  Future<void> setNote(String id, String text) async {
    if (text.isEmpty) {
      await _box.delete(id);
      final m = {...state};
      m.remove(id);
      state = m;
    } else {
      await _box.put(id, text);
      state = {...state, id: text};
    }
  }

  Future<void> reset() async {
    await _box.clear();
    state = {};
  }
}

final packingProvider =
    StateNotifierProvider<PackingNotifier, Map<String, bool>>((ref) => PackingNotifier());

class PackingNotifier extends StateNotifier<Map<String, bool>> {
  PackingNotifier() : super({}) {
    _load();
  }
  final Box _box = Hive.box(boxPacking);

  void _load() {
    final m = <String, bool>{};
    for (final k in _box.keys) {
      m[k.toString()] = _box.get(k) == true;
    }
    state = m;
  }

  bool isChecked(String id) => state[id] ?? false;

  Future<void> toggle(String id) async {
    final v = !(state[id] ?? false);
    await _box.put(id, v);
    state = {...state, id: v};
  }

  Future<void> reset() async {
    await _box.clear();
    state = {};
  }
}

class AppSettings {
  final DateTime? tripStartDate;
  final bool editMode;
  AppSettings({this.tripStartDate, this.editMode = false});

  AppSettings copyWith({DateTime? tripStartDate, bool clearStart = false, bool? editMode}) =>
      AppSettings(
        tripStartDate: clearStart ? null : (tripStartDate ?? this.tripStartDate),
        editMode: editMode ?? this.editMode,
      );
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _load();
  }
  final Box _box = Hive.box(boxSettings);

  void _load() {
    final ts = _box.get('tripStartDate');
    DateTime? d;
    if (ts is String) {
      d = DateTime.tryParse(ts);
    } else if (ts is int) {
      d = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    state = AppSettings(tripStartDate: d);
  }

  Future<void> setTripStartDate(DateTime d) async {
    final justDate = DateTime(d.year, d.month, d.day);
    await _box.put('tripStartDate', justDate.toIso8601String());
    state = state.copyWith(tripStartDate: justDate);
  }

  Future<void> clearTripStartDate() async {
    await _box.delete('tripStartDate');
    state = state.copyWith(clearStart: true);
  }

  void toggleEditMode() {
    state = state.copyWith(editMode: !state.editMode);
  }
}

final activeDayIndexProvider = Provider<int?>((ref) {
  final settings = ref.watch(settingsProvider);
  final tripA = ref.watch(tripProvider);
  if (settings.tripStartDate == null) return null;
  final t = tripA.valueOrNull;
  if (t == null) return null;
  final today = DateTime.now();
  final today0 = DateTime(today.year, today.month, today.day);
  final diff = today0.difference(settings.tripStartDate!).inDays;
  if (diff < 0) return -1;
  if (diff >= t.days.length) return t.days.length;
  return diff;
});

final dayProgressProvider = Provider.family<double, String>((ref, dayId) {
  final tripA = ref.watch(tripProvider);
  final progress = ref.watch(progressProvider);
  final t = tripA.valueOrNull;
  if (t == null) return 0.0;
  final day = t.days.firstWhere((d) => d.id == dayId,
      orElse: () => Day(
          id: '', number: 0, title: '', summary: '', sections: [], alternatives: []));
  final visible = day.allItems.where((i) => !i.hidden && i.type != ItemType.info).toList();
  if (visible.isEmpty) return 0.0;
  final done = visible.where((i) => progress[i.id] == true).length;
  return done / visible.length;
});
