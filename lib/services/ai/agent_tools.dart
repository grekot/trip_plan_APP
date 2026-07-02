import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../models/enums.dart';
import '../../models/trip_models.dart';
import '../../providers/providers.dart';
import 'ai_types.dart';

/// Wynik wykonania narzędzia przez agenta.
/// `content` wraca do modelu; `label` to krótki opis akcji pokazywany w czacie.
class AgentToolOutcome {
  final String content;
  final bool isError;
  final String? label;

  const AgentToolOutcome(this.content, {this.isError = false, this.label});
}

class _ToolError implements Exception {
  final String message;
  const _ToolError(this.message);
}

/// Definicje narzędzi agenta — wspólne dla obu dostawców.
/// Wszystkie operacje modyfikujące używają stabilnych ID (day_id, section_id,
/// item_id), które model MUSI pobrać wcześniej narzędziami odczytu.
final List<AiToolDef> agentToolDefs = [
  // ===== Odczyt =====
  const AiToolDef(
    name: 'get_trip_overview',
    description:
        'Zwraca strukturę całego planu podróży: dni z ich ID, tytułami i sekcjami '
        '(bez szczegółów punktów). Użyj tego na początku, żeby poznać strukturę planu.',
    schema: {'type': 'object', 'properties': {}, 'required': []},
  ),
  const AiToolDef(
    name: 'get_day',
    description:
        'Zwraca pełną zawartość jednego dnia: sekcje i wszystkie punkty z ich ID, '
        'opisami, kosztami i wskazówkami.',
    schema: {
      'type': 'object',
      'properties': {
        'day_id': {'type': 'string', 'description': 'ID dnia (np. "d2") z get_trip_overview'},
      },
      'required': ['day_id'],
    },
  ),
  const AiToolDef(
    name: 'get_extras',
    description: 'Zwraca listę atrakcji dodatkowych (extras) z ich ID.',
    schema: {'type': 'object', 'properties': {}, 'required': []},
  ),
  const AiToolDef(
    name: 'get_packing',
    description: 'Zwraca listę pakowania z ID pozycji i kategoriami.',
    schema: {'type': 'object', 'properties': {}, 'required': []},
  ),
  // ===== Meta =====
  const AiToolDef(
    name: 'update_trip_meta',
    description: 'Zmienia tytuł, podtytuł lub opis całego planu.',
    schema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'subtitle': {'type': 'string'},
        'summary': {'type': 'string'},
      },
      'required': [],
    },
  ),
  // ===== Dni =====
  const AiToolDef(
    name: 'add_day',
    description: 'Dodaje nowy dzień na końcu planu. Zwraca ID nowego dnia.',
    schema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'description': 'Tytuł dnia, np. "Dzień 5 — Lublana"'},
      },
      'required': ['title'],
    },
  ),
  const AiToolDef(
    name: 'update_day',
    description: 'Zmienia tytuł lub opis (summary) istniejącego dnia.',
    schema: {
      'type': 'object',
      'properties': {
        'day_id': {'type': 'string'},
        'title': {'type': 'string'},
        'summary': {'type': 'string'},
      },
      'required': ['day_id'],
    },
  ),
  const AiToolDef(
    name: 'delete_day',
    description: 'Usuwa cały dzień wraz z sekcjami i punktami. Operacja nieodwracalna — '
        'wykonuj tylko na wyraźne polecenie użytkownika.',
    schema: {
      'type': 'object',
      'properties': {
        'day_id': {'type': 'string'},
      },
      'required': ['day_id'],
    },
  ),
  // ===== Sekcje =====
  const AiToolDef(
    name: 'add_section',
    description: 'Dodaje nową sekcję (np. "Rano", "Popołudnie") do dnia. Zwraca ID sekcji.',
    schema: {
      'type': 'object',
      'properties': {
        'day_id': {'type': 'string'},
        'title': {'type': 'string'},
        'time_window': {'type': 'string', 'description': 'Opcjonalne okno czasowe, np. "9:00–12:00"'},
      },
      'required': ['day_id', 'title'],
    },
  ),
  const AiToolDef(
    name: 'update_section',
    description: 'Zmienia tytuł lub okno czasowe sekcji.',
    schema: {
      'type': 'object',
      'properties': {
        'section_id': {'type': 'string'},
        'title': {'type': 'string'},
        'time_window': {'type': 'string'},
      },
      'required': ['section_id'],
    },
  ),
  const AiToolDef(
    name: 'delete_section',
    description: 'Usuwa sekcję wraz z punktami. Operacja nieodwracalna — tylko na wyraźne '
        'polecenie użytkownika.',
    schema: {
      'type': 'object',
      'properties': {
        'section_id': {'type': 'string'},
      },
      'required': ['section_id'],
    },
  ),
  // ===== Punkty =====
  const AiToolDef(
    name: 'add_item',
    description: 'Dodaje nowy punkt planu do wskazanej sekcji. Zwraca ID nowego punktu.',
    schema: {
      'type': 'object',
      'properties': {
        'day_id': {'type': 'string'},
        'section_id': {'type': 'string'},
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'type': {
          'type': 'string',
          'enum': ['drive', 'sightseeing', 'hike', 'meal', 'lodging', 'swim', 'info'],
          'description': 'Typ punktu: drive=dojazd, sightseeing=zwiedzanie, hike=trek, '
              'meal=posiłek, lodging=nocleg, swim=kąpiel, info=informacja',
        },
        'cost_eur': {'type': 'integer', 'description': 'Szacunkowy koszt w EUR'},
        'duration': {'type': 'string', 'description': 'Czas trwania, np. "2h"'},
        'tips': {'type': 'array', 'items': {'type': 'string'}},
        'position': {
          'type': 'integer',
          'description': 'Pozycja na liście sekcji (0 = początek). Domyślnie na końcu.',
        },
      },
      'required': ['day_id', 'section_id', 'title'],
    },
  ),
  const AiToolDef(
    name: 'update_item',
    description: 'Modyfikuje istniejący punkt planu. Podaj tylko pola do zmiany. '
        'Pole tips zastępuje całą listę wskazówek.',
    schema: {
      'type': 'object',
      'properties': {
        'item_id': {'type': 'string'},
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'type': {
          'type': 'string',
          'enum': ['drive', 'sightseeing', 'hike', 'meal', 'lodging', 'swim', 'info'],
        },
        'cost_eur': {'type': 'integer'},
        'duration': {'type': 'string'},
        'tips': {'type': 'array', 'items': {'type': 'string'}},
        'hidden': {'type': 'boolean', 'description': 'true = ukryj punkt (miękkie usunięcie)'},
      },
      'required': ['item_id'],
    },
  ),
  const AiToolDef(
    name: 'delete_item',
    description: 'Trwale usuwa punkt planu. Jeśli użytkownik chce tylko pominąć punkt, '
        'użyj update_item z hidden=true.',
    schema: {
      'type': 'object',
      'properties': {
        'item_id': {'type': 'string'},
      },
      'required': ['item_id'],
    },
  ),
  const AiToolDef(
    name: 'move_item',
    description: 'Przenosi punkt do innej sekcji (może być w innym dniu).',
    schema: {
      'type': 'object',
      'properties': {
        'item_id': {'type': 'string'},
        'target_day_id': {'type': 'string'},
        'target_section_id': {'type': 'string'},
        'position': {'type': 'integer', 'description': 'Pozycja docelowa (0 = początek). Domyślnie koniec.'},
      },
      'required': ['item_id', 'target_day_id', 'target_section_id'],
    },
  ),
  // ===== Pakowanie =====
  const AiToolDef(
    name: 'add_packing_item',
    description: 'Dodaje pozycję do listy pakowania.',
    schema: {
      'type': 'object',
      'properties': {
        'category': {'type': 'string', 'description': 'Kategoria, np. "Dokumenty", "Ubrania"'},
        'text': {'type': 'string'},
      },
      'required': ['category', 'text'],
    },
  ),
  const AiToolDef(
    name: 'delete_packing_item',
    description: 'Usuwa pozycję z listy pakowania.',
    schema: {
      'type': 'object',
      'properties': {
        'packing_id': {'type': 'string'},
      },
      'required': ['packing_id'],
    },
  ),
  // ===== Atrakcje extra =====
  const AiToolDef(
    name: 'add_extra',
    description: 'Dodaje atrakcję dodatkową (extra) do puli pomysłów poza planem dziennym.',
    schema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'category': {
          'type': 'string',
          'enum': ['short', 'halfday', 'evening', 'fullday'],
          'description': 'short=1-2h, halfday=3-5h, evening=popołudnie/wieczór, fullday=cały dzień',
        },
        'total_cost_eur': {'type': 'integer'},
        'driving_time': {'type': 'string', 'description': 'Czas dojazdu, np. "45 min"'},
        'duration': {'type': 'string'},
      },
      'required': ['title', 'description', 'category'],
    },
  ),
  const AiToolDef(
    name: 'delete_extra',
    description: 'Usuwa atrakcję dodatkową. Tylko na wyraźne polecenie użytkownika.',
    schema: {
      'type': 'object',
      'properties': {
        'extra_id': {'type': 'string'},
      },
      'required': ['extra_id'],
    },
  ),
];

/// Wykonawca narzędzi agenta — tłumaczy wywołania (po ID) na operacje
/// istniejącego [TripNotifier] (po indeksach) i zwraca wyniki jako JSON.
class AgentToolExecutor {
  final TripNotifier notifier;

  AgentToolExecutor(this.notifier);

  Trip get _trip {
    final t = notifier.current;
    if (t == null) {
      throw const _ToolError('Brak aktywnego planu podróży.');
    }
    return t;
  }

  Future<AgentToolOutcome> execute(String name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case 'get_trip_overview':
          return AgentToolOutcome(_overviewJson());
        case 'get_day':
          return AgentToolOutcome(_dayJson(_str(args, 'day_id')));
        case 'get_extras':
          return AgentToolOutcome(
              jsonEncode(_trip.extras.map((e) => e.toJson()).toList()));
        case 'get_packing':
          return AgentToolOutcome(
              jsonEncode(_trip.packing.map((p) => p.toJson()).toList()));
        case 'update_trip_meta':
          return await _updateTripMeta(args);
        case 'add_day':
          return await _addDay(args);
        case 'update_day':
          return await _updateDay(args);
        case 'delete_day':
          return await _deleteDay(args);
        case 'add_section':
          return await _addSection(args);
        case 'update_section':
          return await _updateSection(args);
        case 'delete_section':
          return await _deleteSection(args);
        case 'add_item':
          return await _addItem(args);
        case 'update_item':
          return await _updateItem(args);
        case 'delete_item':
          return await _deleteItem(args);
        case 'move_item':
          return await _moveItem(args);
        case 'add_packing_item':
          return await _addPackingItem(args);
        case 'delete_packing_item':
          return await _deletePackingItem(args);
        case 'add_extra':
          return await _addExtra(args);
        case 'delete_extra':
          return await _deleteExtra(args);
        default:
          return AgentToolOutcome('Nieznane narzędzie: $name', isError: true);
      }
    } on _ToolError catch (e) {
      return AgentToolOutcome(e.message, isError: true);
    } catch (e) {
      return AgentToolOutcome('Błąd wykonania narzędzia $name: $e', isError: true);
    }
  }

  // ===== Helpers =====

  String _str(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! String || v.isEmpty) {
      throw _ToolError('Brak wymaganego parametru "$key".');
    }
    return v;
  }

  int _dayIdx(String dayId) {
    final idx = _trip.days.indexWhere((d) => d.id == dayId);
    if (idx < 0) throw _ToolError('Nie znaleziono dnia o ID "$dayId".');
    return idx;
  }

  (int, int) _sectionIdx(String sectionId) {
    final t = _trip;
    for (var d = 0; d < t.days.length; d++) {
      for (var s = 0; s < t.days[d].sections.length; s++) {
        if (t.days[d].sections[s].id == sectionId) return (d, s);
      }
    }
    throw _ToolError('Nie znaleziono sekcji o ID "$sectionId".');
  }

  (int, int, int) _itemIdx(String itemId) {
    final t = _trip;
    for (var d = 0; d < t.days.length; d++) {
      for (var s = 0; s < t.days[d].sections.length; s++) {
        for (var i = 0; i < t.days[d].sections[s].items.length; i++) {
          if (t.days[d].sections[s].items[i].id == itemId) return (d, s, i);
        }
      }
    }
    throw _ToolError('Nie znaleziono punktu o ID "$itemId".');
  }

  String _overviewJson() {
    final t = _trip;
    return jsonEncode({
      'title': t.title,
      if (t.subtitle != null) 'subtitle': t.subtitle,
      if (t.summary != null) 'summary': t.summary,
      'days': [
        for (final d in t.days)
          {
            'id': d.id,
            'number': d.number,
            'title': d.title,
            'summary': d.summary,
            'sections': [
              for (final s in d.sections)
                {
                  'id': s.id,
                  'title': s.title,
                  if (s.timeWindow != null) 'timeWindow': s.timeWindow,
                  'itemCount': s.items.length,
                },
            ],
          },
      ],
      'extrasCount': t.extras.length,
      'packingCount': t.packing.length,
    });
  }

  String _dayJson(String dayId) => jsonEncode(_trip.days[_dayIdx(dayId)].toJson());

  // ===== Mutacje =====

  Future<AgentToolOutcome> _updateTripMeta(Map<String, dynamic> args) async {
    await notifier.updateMeta(
      title: args['title'] as String?,
      subtitle: args['subtitle'] as String?,
      summary: args['summary'] as String?,
    );
    return const AgentToolOutcome('OK', label: 'Zmieniono dane planu');
  }

  Future<AgentToolOutcome> _addDay(Map<String, dynamic> args) async {
    final title = _str(args, 'title');
    await notifier.addDay(title: title);
    final d = _trip.days.last;
    return AgentToolOutcome(
      jsonEncode({'day_id': d.id, 'number': d.number}),
      label: 'Dodano dzień: $title',
    );
  }

  Future<AgentToolOutcome> _updateDay(Map<String, dynamic> args) async {
    final idx = _dayIdx(_str(args, 'day_id'));
    await notifier.updateDay(idx,
        title: args['title'] as String?, summary: args['summary'] as String?);
    return AgentToolOutcome('OK',
        label: 'Zmieniono dzień: ${_trip.days[idx].title}');
  }

  Future<AgentToolOutcome> _deleteDay(Map<String, dynamic> args) async {
    final idx = _dayIdx(_str(args, 'day_id'));
    final title = _trip.days[idx].title;
    await notifier.deleteDay(idx);
    return AgentToolOutcome('OK', label: 'Usunięto dzień: $title');
  }

  Future<AgentToolOutcome> _addSection(Map<String, dynamic> args) async {
    final idx = _dayIdx(_str(args, 'day_id'));
    final title = _str(args, 'title');
    await notifier.addSection(idx,
        title: title, timeWindow: args['time_window'] as String?);
    final sec = _trip.days[idx].sections.last;
    return AgentToolOutcome(
      jsonEncode({'section_id': sec.id}),
      label: 'Dodano sekcję „$title” (${_trip.days[idx].title})',
    );
  }

  Future<AgentToolOutcome> _updateSection(Map<String, dynamic> args) async {
    final (d, s) = _sectionIdx(_str(args, 'section_id'));
    await notifier.updateSection(d, s,
        title: args['title'] as String?,
        timeWindow: args['time_window'] as String?);
    return AgentToolOutcome('OK',
        label: 'Zmieniono sekcję: ${_trip.days[d].sections[s].title}');
  }

  Future<AgentToolOutcome> _deleteSection(Map<String, dynamic> args) async {
    final (d, s) = _sectionIdx(_str(args, 'section_id'));
    final title = _trip.days[d].sections[s].title;
    await notifier.deleteSection(d, s);
    return AgentToolOutcome('OK', label: 'Usunięto sekcję: $title');
  }

  Future<AgentToolOutcome> _addItem(Map<String, dynamic> args) async {
    final d = _dayIdx(_str(args, 'day_id'));
    final sectionId = _str(args, 'section_id');
    final (sd, s) = _sectionIdx(sectionId);
    if (sd != d) {
      throw _ToolError('Sekcja "$sectionId" nie należy do dnia "${args['day_id']}".');
    }
    final title = _str(args, 'title');
    final item = Item(
      id: 'custom.${const Uuid().v4()}',
      title: title,
      description: args['description'] as String?,
      type: ItemType.fromString(args['type'] as String?),
      costEur: (args['cost_eur'] as num?)?.toInt(),
      duration: args['duration'] as String?,
      tips: (args['tips'] as List? ?? []).map((e) => e.toString()).toList(),
      userAdded: true,
    );
    await notifier.addItem(d, s, item);
    // Opcjonalne wstawienie na konkretną pozycję (addItem dodaje na końcu).
    final position = (args['position'] as num?)?.toInt();
    final itemCount = _trip.days[d].sections[s].items.length;
    if (position != null && position >= 0 && position < itemCount - 1) {
      await notifier.reorderItems(d, s, itemCount - 1, position);
    }
    return AgentToolOutcome(
      jsonEncode({'item_id': item.id}),
      label: 'Dodano punkt „$title” (${_trip.days[d].title})',
    );
  }

  Future<AgentToolOutcome> _updateItem(Map<String, dynamic> args) async {
    final (d, s, i) = _itemIdx(_str(args, 'item_id'));
    final old = _trip.days[d].sections[s].items[i];
    final updated = Item(
      id: old.id,
      title: args['title'] as String? ?? old.title,
      description: args['description'] as String? ?? old.description,
      type: args['type'] != null
          ? ItemType.fromString(args['type'] as String)
          : old.type,
      location: old.location,
      locations: old.locations,
      costEur: (args['cost_eur'] as num?)?.toInt() ?? old.costEur,
      duration: args['duration'] as String? ?? old.duration,
      tips: args['tips'] != null
          ? (args['tips'] as List).map((e) => e.toString()).toList()
          : old.tips,
      hidden: args['hidden'] as bool? ?? old.hidden,
      userAdded: old.userAdded,
    );
    await notifier.updateItem(d, s, i, updated);
    return AgentToolOutcome('OK', label: 'Zmieniono punkt: ${updated.title}');
  }

  Future<AgentToolOutcome> _deleteItem(Map<String, dynamic> args) async {
    final (d, s, i) = _itemIdx(_str(args, 'item_id'));
    final title = _trip.days[d].sections[s].items[i].title;
    await notifier.deleteItem(d, s, i);
    return AgentToolOutcome('OK', label: 'Usunięto punkt: $title');
  }

  Future<AgentToolOutcome> _moveItem(Map<String, dynamic> args) async {
    final (d, s, i) = _itemIdx(_str(args, 'item_id'));
    final targetDay = _dayIdx(_str(args, 'target_day_id'));
    final targetSectionId = _str(args, 'target_section_id');
    final item = _trip.days[d].sections[s].items[i];

    await notifier.deleteItem(d, s, i);
    // Indeksy sekcji mogły się zmienić tylko przy usunięciu sekcji — tu
    // usuwamy punkt, więc wystarczy ponowne rozwiązanie ID po delete.
    final (td, ts) = _sectionIdx(targetSectionId);
    if (td != targetDay) {
      // Przywróć punkt do źródła, żeby nie zginął.
      await notifier.addItem(d, s, item);
      throw _ToolError(
          'Sekcja "$targetSectionId" nie należy do dnia "${args['target_day_id']}".');
    }
    await notifier.addItem(td, ts, item);
    final position = (args['position'] as num?)?.toInt();
    final itemCount = _trip.days[td].sections[ts].items.length;
    if (position != null && position >= 0 && position < itemCount - 1) {
      await notifier.reorderItems(td, ts, itemCount - 1, position);
    }
    return AgentToolOutcome('OK',
        label: 'Przeniesiono „${item.title}” → ${_trip.days[td].title}');
  }

  Future<AgentToolOutcome> _addPackingItem(Map<String, dynamic> args) async {
    final text = _str(args, 'text');
    final item = PackingItem(
      id: 'custom.${const Uuid().v4()}',
      category: _str(args, 'category'),
      text: text,
      userAdded: true,
    );
    await notifier.addPackingItem(item);
    return AgentToolOutcome(
      jsonEncode({'packing_id': item.id}),
      label: 'Dodano do pakowania: $text',
    );
  }

  Future<AgentToolOutcome> _deletePackingItem(Map<String, dynamic> args) async {
    final id = _str(args, 'packing_id');
    final idx = _trip.packing.indexWhere((p) => p.id == id);
    if (idx < 0) throw _ToolError('Nie znaleziono pozycji pakowania o ID "$id".');
    final text = _trip.packing[idx].text;
    await notifier.deletePackingItem(idx);
    return AgentToolOutcome('OK', label: 'Usunięto z pakowania: $text');
  }

  Future<AgentToolOutcome> _addExtra(Map<String, dynamic> args) async {
    final title = _str(args, 'title');
    final extra = ExtraAttraction(
      id: 'custom.${const Uuid().v4()}',
      title: title,
      category: ExtraCategory.fromString(args['category'] as String?),
      drivingTime: args['driving_time'] as String?,
      totalCostEur: (args['total_cost_eur'] as num?)?.toInt() ?? 0,
      description: _str(args, 'description'),
      duration: args['duration'] as String?,
    );
    await notifier.addExtra(extra);
    return AgentToolOutcome(
      jsonEncode({'extra_id': extra.id}),
      label: 'Dodano atrakcję extra: $title',
    );
  }

  Future<AgentToolOutcome> _deleteExtra(Map<String, dynamic> args) async {
    final id = _str(args, 'extra_id');
    final idx = _trip.extras.indexWhere((e) => e.id == id);
    if (idx < 0) throw _ToolError('Nie znaleziono atrakcji extra o ID "$id".');
    final title = _trip.extras[idx].title;
    await notifier.deleteExtra(idx);
    return AgentToolOutcome('OK', label: 'Usunięto atrakcję extra: $title');
  }
}
