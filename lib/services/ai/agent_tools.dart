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

/// Narzędzia tylko-do-odczytu — nie modyfikują planu (używane do decyzji,
/// czy przed wykonaniem tury trzeba zrobić snapshot do historii zmian).
const Set<String> readOnlyAgentTools = {
  'get_trip_overview',
  'get_day',
  'get_extras',
  'get_packing',
  'get_practical',
  'get_emergency',
  'get_contingency',
};

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
  const AiToolDef(
    name: 'get_emergency',
    description: 'Zwraca listę kontaktów alarmowych (telefony, ambasada) z ich ID.',
    schema: {'type': 'object', 'properties': {}, 'required': []},
  ),
  const AiToolDef(
    name: 'get_contingency',
    description: 'Zwraca plany awaryjne (plany B): sytuacja wyzwalająca + opcje, z ID.',
    schema: {'type': 'object', 'properties': {}, 'required': []},
  ),
  const AiToolDef(
    name: 'get_practical',
    description:
        'Zwraca sekcję "practical" planu — swobodny JSON z informacjami praktycznymi. '
        'Typowe klucze: "rozmowki" (rozmówki EN z kategoriami i zwrotami), '
        '"wawozy" (opisy wąwozów), "info", "menu". Podaj klucz, żeby pobrać jedną '
        'gałąź, albo pomiń, żeby zobaczyć całość.',
    schema: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description': 'Opcjonalny klucz gałęzi (np. "rozmowki", "wawozy"). '
              'Bez klucza zwraca całą sekcję practical.',
        },
      },
      'required': [],
    },
  ),
  const AiToolDef(
    name: 'update_practical',
    description:
        'Podmienia JEDNĄ gałąź sekcji "practical" (np. "rozmowki" albo "wawozy") '
        'na nową zawartość. UWAGA: podmieniasz całą gałąź — ZAWSZE najpierw pobierz '
        'aktualną zawartość przez get_practical i zmodyfikuj ją, zamiast budować od zera. '
        'Zachowuj istniejącą strukturę (te same nazwy pól).',
    schema: {
      'type': 'object',
      'properties': {
        'key': {'type': 'string', 'description': 'Klucz gałęzi, np. "rozmowki"'},
        'value': {
          'description': 'Nowa zawartość gałęzi (dowolny JSON — obiekt lub lista). '
              'Ma zastąpić bieżącą wartość pod tym kluczem.',
        },
      },
      'required': ['key', 'value'],
    },
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
    name: 'move_day',
    description: 'Zmienia kolejność dni — przenosi dzień na wskazaną pozycję '
        '(0 = pierwszy). Numery dni są automatycznie przeliczane; tytuły dni '
        'zawierające numer (np. "Dzień 3 — …") NIE zmieniają się same — '
        'zaktualizuj je przez update_day, jeśli trzeba.',
    schema: {
      'type': 'object',
      'properties': {
        'day_id': {'type': 'string'},
        'position': {'type': 'integer', 'description': 'Pozycja docelowa (0 = początek)'},
      },
      'required': ['day_id', 'position'],
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
    name: 'move_section',
    description: 'Zmienia kolejność sekcji w obrębie dnia — przenosi sekcję na '
        'wskazaną pozycję (0 = pierwsza).',
    schema: {
      'type': 'object',
      'properties': {
        'section_id': {'type': 'string'},
        'position': {'type': 'integer', 'description': 'Pozycja docelowa (0 = początek)'},
      },
      'required': ['section_id', 'position'],
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
        'location_name': {'type': 'string', 'description': 'Nazwa lokalizacji (wymaga też lat i lng)'},
        'lat': {'type': 'number', 'description': 'Szerokość geograficzna'},
        'lng': {'type': 'number', 'description': 'Długość geograficzna'},
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
        'location_name': {
          'type': 'string',
          'description': 'Nazwa lokalizacji — ustawia/zamienia lokalizację punktu '
              '(wymaga też lat i lng)',
        },
        'lat': {'type': 'number'},
        'lng': {'type': 'number'},
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
  // ===== Alternatywy dnia =====
  const AiToolDef(
    name: 'add_alternative',
    description: 'Dodaje punkt alternatywny do dnia (pula opcji „na wypadek gdyby”, '
        'poza sekcjami). Zwraca ID nowej alternatywy.',
    schema: {
      'type': 'object',
      'properties': {
        'day_id': {'type': 'string'},
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'type': {
          'type': 'string',
          'enum': ['drive', 'sightseeing', 'hike', 'meal', 'lodging', 'swim', 'info'],
        },
        'cost_eur': {'type': 'integer'},
        'duration': {'type': 'string'},
        'tips': {'type': 'array', 'items': {'type': 'string'}},
        'location_name': {'type': 'string', 'description': 'Nazwa lokalizacji (wymaga też lat i lng)'},
        'lat': {'type': 'number'},
        'lng': {'type': 'number'},
      },
      'required': ['day_id', 'title'],
    },
  ),
  const AiToolDef(
    name: 'update_alternative',
    description: 'Modyfikuje punkt alternatywny dnia (ID z listy "alternatives" '
        'w get_day). Podaj tylko pola do zmiany.',
    schema: {
      'type': 'object',
      'properties': {
        'alternative_id': {'type': 'string'},
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'type': {
          'type': 'string',
          'enum': ['drive', 'sightseeing', 'hike', 'meal', 'lodging', 'swim', 'info'],
        },
        'cost_eur': {'type': 'integer'},
        'duration': {'type': 'string'},
        'tips': {'type': 'array', 'items': {'type': 'string'}},
        'location_name': {'type': 'string'},
        'lat': {'type': 'number'},
        'lng': {'type': 'number'},
      },
      'required': ['alternative_id'],
    },
  ),
  const AiToolDef(
    name: 'delete_alternative',
    description: 'Usuwa punkt alternatywny dnia. Tylko na wyraźne polecenie użytkownika.',
    schema: {
      'type': 'object',
      'properties': {
        'alternative_id': {'type': 'string'},
      },
      'required': ['alternative_id'],
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
    name: 'update_packing_item',
    description: 'Zmienia tekst lub kategorię pozycji na liście pakowania.',
    schema: {
      'type': 'object',
      'properties': {
        'packing_id': {'type': 'string'},
        'category': {'type': 'string'},
        'text': {'type': 'string'},
      },
      'required': ['packing_id'],
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
        'best_for': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Dla kogo najlepsze, np. ["dzieci", "upalny dzień"]',
        },
        'location_name': {'type': 'string', 'description': 'Nazwa lokalizacji (wymaga też lat i lng)'},
        'lat': {'type': 'number'},
        'lng': {'type': 'number'},
      },
      'required': ['title', 'description', 'category'],
    },
  ),
  const AiToolDef(
    name: 'update_extra',
    description: 'Modyfikuje istniejącą atrakcję extra. Podaj tylko pola do zmiany. '
        'Pole best_for zastępuje całą listę.',
    schema: {
      'type': 'object',
      'properties': {
        'extra_id': {'type': 'string'},
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'category': {
          'type': 'string',
          'enum': ['short', 'halfday', 'evening', 'fullday'],
        },
        'total_cost_eur': {'type': 'integer'},
        'driving_time': {'type': 'string'},
        'duration': {'type': 'string'},
        'best_for': {'type': 'array', 'items': {'type': 'string'}},
        'location_name': {'type': 'string'},
        'lat': {'type': 'number'},
        'lng': {'type': 'number'},
      },
      'required': ['extra_id'],
    },
  ),
  const AiToolDef(
    name: 'set_extra_used',
    description: 'Oznacza atrakcję extra jako wykorzystaną (dodaną do planu dziennego) '
        'lub cofa oznaczenie. Używaj po dodaniu atrakcji extra jako punktu planu — '
        'atrakcja zostaje na liście, ale UI pokazuje ją jako „w planie”.',
    schema: {
      'type': 'object',
      'properties': {
        'extra_id': {'type': 'string'},
        'used': {'type': 'boolean', 'description': 'true = wykorzystana, false = cofnij oznaczenie'},
      },
      'required': ['extra_id', 'used'],
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
  // ===== Kontakty alarmowe =====
  const AiToolDef(
    name: 'add_emergency',
    description: 'Dodaje kontakt alarmowy (telefon lub ambasadę).',
    schema: {
      'type': 'object',
      'properties': {
        'label': {'type': 'string', 'description': 'Nazwa, np. "Pogotowie górskie"'},
        'value': {'type': 'string', 'description': 'Numer telefonu lub adres'},
        'type': {
          'type': 'string',
          'enum': ['phone', 'embassy'],
          'description': 'phone=telefon, embassy=ambasada',
        },
      },
      'required': ['label', 'value'],
    },
  ),
  const AiToolDef(
    name: 'update_emergency',
    description: 'Modyfikuje kontakt alarmowy. Podaj tylko pola do zmiany.',
    schema: {
      'type': 'object',
      'properties': {
        'emergency_id': {'type': 'string'},
        'label': {'type': 'string'},
        'value': {'type': 'string'},
        'type': {'type': 'string', 'enum': ['phone', 'embassy']},
      },
      'required': ['emergency_id'],
    },
  ),
  const AiToolDef(
    name: 'delete_emergency',
    description: 'Usuwa kontakt alarmowy. Tylko na wyraźne polecenie użytkownika.',
    schema: {
      'type': 'object',
      'properties': {
        'emergency_id': {'type': 'string'},
      },
      'required': ['emergency_id'],
    },
  ),
  // ===== Plany B (contingency) =====
  const AiToolDef(
    name: 'add_contingency',
    description: 'Dodaje plan awaryjny (plan B): sytuacja wyzwalająca + lista opcji. '
        'Z day_id plan pokazuje się też na ekranie tego dnia.',
    schema: {
      'type': 'object',
      'properties': {
        'trigger': {'type': 'string', 'description': 'Sytuacja, np. "Deszcz w dniu górskim"'},
        'options': {'type': 'array', 'items': {'type': 'string'}, 'description': 'Opcje działania'},
        'day_id': {
          'type': 'string',
          'description': 'Opcjonalne przypisanie do dnia (ID z get_trip_overview)',
        },
        'locations': {
          'type': 'array',
          'description': 'Lokalizacje planu B — klikalne przyciski mapy',
          'items': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'lat': {'type': 'number'},
              'lng': {'type': 'number'},
            },
            'required': ['name', 'lat', 'lng'],
          },
        },
      },
      'required': ['trigger', 'options'],
    },
  ),
  const AiToolDef(
    name: 'update_contingency',
    description: 'Modyfikuje plan awaryjny. Pole options zastępuje całą listę opcji. '
        'day_id="" (pusty string) odpina plan od dnia.',
    schema: {
      'type': 'object',
      'properties': {
        'contingency_id': {'type': 'string'},
        'trigger': {'type': 'string'},
        'options': {'type': 'array', 'items': {'type': 'string'}},
        'day_id': {
          'type': 'string',
          'description': 'Przypisanie do dnia; pusty string usuwa przypisanie',
        },
        'locations': {
          'type': 'array',
          'description': 'Zastępuje CAŁĄ listę lokalizacji (pusta lista = usuń wszystkie)',
          'items': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'lat': {'type': 'number'},
              'lng': {'type': 'number'},
            },
            'required': ['name', 'lat', 'lng'],
          },
        },
      },
      'required': ['contingency_id'],
    },
  ),
  const AiToolDef(
    name: 'delete_contingency',
    description: 'Usuwa plan awaryjny. Tylko na wyraźne polecenie użytkownika.',
    schema: {
      'type': 'object',
      'properties': {
        'contingency_id': {'type': 'string'},
      },
      'required': ['contingency_id'],
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
        case 'get_practical':
          return _getPractical(args);
        case 'update_practical':
          return await _updatePractical(args);
        case 'get_emergency':
          return AgentToolOutcome(
              jsonEncode(_trip.emergency.map((e) => e.toJson()).toList()));
        case 'get_contingency':
          return AgentToolOutcome(
              jsonEncode(_trip.contingency.map((c) => c.toJson()).toList()));
        case 'update_trip_meta':
          return await _updateTripMeta(args);
        case 'add_day':
          return await _addDay(args);
        case 'update_day':
          return await _updateDay(args);
        case 'move_day':
          return await _moveDay(args);
        case 'delete_day':
          return await _deleteDay(args);
        case 'add_section':
          return await _addSection(args);
        case 'update_section':
          return await _updateSection(args);
        case 'move_section':
          return await _moveSection(args);
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
        case 'add_alternative':
          return await _addAlternative(args);
        case 'update_alternative':
          return await _updateAlternative(args);
        case 'delete_alternative':
          return await _deleteAlternative(args);
        case 'set_extra_used':
          return await _setExtraUsed(args);
        case 'add_packing_item':
          return await _addPackingItem(args);
        case 'update_packing_item':
          return await _updatePackingItem(args);
        case 'delete_packing_item':
          return await _deletePackingItem(args);
        case 'add_extra':
          return await _addExtra(args);
        case 'update_extra':
          return await _updateExtra(args);
        case 'delete_extra':
          return await _deleteExtra(args);
        case 'add_emergency':
          return await _addEmergency(args);
        case 'update_emergency':
          return await _updateEmergency(args);
        case 'delete_emergency':
          return await _deleteEmergency(args);
        case 'add_contingency':
          return await _addContingency(args);
        case 'update_contingency':
          return await _updateContingency(args);
        case 'delete_contingency':
          return await _deleteContingency(args);
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

  /// Buduje [Location] z parametrów location_name/lat/lng — wszystkie trzy
  /// wymagane razem. Zwraca null, gdy nie podano żadnego.
  Location? _locationFromArgs(Map<String, dynamic> args) {
    final name = args['location_name'] as String?;
    final lat = (args['lat'] as num?)?.toDouble();
    final lng = (args['lng'] as num?)?.toDouble();
    if (name == null && lat == null && lng == null) return null;
    if (name == null || lat == null || lng == null) {
      throw const _ToolError(
          'Lokalizacja wymaga wszystkich trzech pól: location_name, lat i lng.');
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw const _ToolError('Współrzędne poza zakresem (lat ±90, lng ±180).');
    }
    return Location(name: name, lat: lat, lng: lng);
  }

  (int, int) _altIdx(String altId) {
    final t = _trip;
    for (var d = 0; d < t.days.length; d++) {
      for (var a = 0; a < t.days[d].alternatives.length; a++) {
        if (t.days[d].alternatives[a].id == altId) return (d, a);
      }
    }
    throw _ToolError('Nie znaleziono alternatywy o ID "$altId".');
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
      'emergencyCount': t.emergency.length,
      'contingencyCount': t.contingency.length,
      // Klucze sekcji practical (rozmówki, wąwozy, info…) — zawartość przez
      // get_practical.
      'practicalKeys': t.practical.keys.toList(),
    });
  }

  AgentToolOutcome _getPractical(Map<String, dynamic> args) {
    final key = args['key'] as String?;
    if (key == null || key.isEmpty) {
      return AgentToolOutcome(jsonEncode(_trip.practical));
    }
    if (!_trip.practical.containsKey(key)) {
      throw _ToolError('Brak klucza "$key" w practical. '
          'Dostępne: ${_trip.practical.keys.join(", ")}.');
    }
    return AgentToolOutcome(jsonEncode(_trip.practical[key]));
  }

  Future<AgentToolOutcome> _updatePractical(Map<String, dynamic> args) async {
    final key = _str(args, 'key');
    if (!args.containsKey('value')) {
      throw const _ToolError('Brak wymaganego parametru "value".');
    }
    final newPractical = Map<String, dynamic>.from(_trip.practical);
    newPractical[key] = args['value'];
    await notifier.updatePractical(newPractical);
    return AgentToolOutcome('OK', label: 'Zmieniono practical: $key');
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

  /// Przelicza `oldIdx → position` na semantykę [TripNotifier.reorderDays]
  /// (styl ReorderableListView: gdy cel jest za źródłem, indeks przesuwa się
  /// o 1 po usunięciu elementu ze starej pozycji).
  int _reorderTarget(int oldIdx, int position) =>
      position > oldIdx ? position + 1 : position;

  Future<AgentToolOutcome> _moveDay(Map<String, dynamic> args) async {
    final oldIdx = _dayIdx(_str(args, 'day_id'));
    final position =
        ((args['position'] as num?)?.toInt() ?? 0).clamp(0, _trip.days.length - 1);
    final title = _trip.days[oldIdx].title;
    if (position != oldIdx) {
      await notifier.reorderDays(oldIdx, _reorderTarget(oldIdx, position));
      // Przelicz numery dni po zmianie kolejności (number = pozycja + 1).
      for (var i = 0; i < _trip.days.length; i++) {
        if (_trip.days[i].number != i + 1) {
          await notifier.updateDay(i, number: i + 1);
        }
      }
    }
    return AgentToolOutcome('OK',
        label: 'Przeniesiono dzień „$title” na pozycję ${position + 1}');
  }

  Future<AgentToolOutcome> _moveSection(Map<String, dynamic> args) async {
    final (d, oldIdx) = _sectionIdx(_str(args, 'section_id'));
    final sections = _trip.days[d].sections;
    final position =
        ((args['position'] as num?)?.toInt() ?? 0).clamp(0, sections.length - 1);
    final title = sections[oldIdx].title;
    if (position != oldIdx) {
      await notifier.reorderSections(d, oldIdx, _reorderTarget(oldIdx, position));
    }
    return AgentToolOutcome('OK',
        label: 'Przeniesiono sekcję „$title” na pozycję ${position + 1}');
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
      location: _locationFromArgs(args),
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

  /// Buduje zaktualizowany [Item] na bazie [old] i podanych pól args
  /// (wspólne dla update_item i update_alternative).
  Item _mergedItem(Item old, Map<String, dynamic> args) => Item(
        id: old.id,
        title: args['title'] as String? ?? old.title,
        description: args['description'] as String? ?? old.description,
        type: args['type'] != null
            ? ItemType.fromString(args['type'] as String)
            : old.type,
        location: _locationFromArgs(args) ?? old.location,
        locations: old.locations,
        costEur: (args['cost_eur'] as num?)?.toInt() ?? old.costEur,
        duration: args['duration'] as String? ?? old.duration,
        tips: args['tips'] != null
            ? (args['tips'] as List).map((e) => e.toString()).toList()
            : old.tips,
        hidden: args['hidden'] as bool? ?? old.hidden,
        userAdded: old.userAdded,
      );

  Future<AgentToolOutcome> _updateItem(Map<String, dynamic> args) async {
    final (d, s, i) = _itemIdx(_str(args, 'item_id'));
    final updated = _mergedItem(_trip.days[d].sections[s].items[i], args);
    await notifier.updateItem(d, s, i, updated);
    return AgentToolOutcome('OK', label: 'Zmieniono punkt: ${updated.title}');
  }

  Future<AgentToolOutcome> _addAlternative(Map<String, dynamic> args) async {
    final d = _dayIdx(_str(args, 'day_id'));
    final title = _str(args, 'title');
    final alt = Item(
      id: 'custom.${const Uuid().v4()}',
      title: title,
      description: args['description'] as String?,
      type: ItemType.fromString(args['type'] as String?),
      location: _locationFromArgs(args),
      costEur: (args['cost_eur'] as num?)?.toInt(),
      duration: args['duration'] as String?,
      tips: (args['tips'] as List? ?? []).map((e) => e.toString()).toList(),
      userAdded: true,
    );
    await notifier.addAlternative(d, alt);
    return AgentToolOutcome(
      jsonEncode({'alternative_id': alt.id}),
      label: 'Dodano alternatywę „$title” (${_trip.days[d].title})',
    );
  }

  Future<AgentToolOutcome> _updateAlternative(Map<String, dynamic> args) async {
    final (d, a) = _altIdx(_str(args, 'alternative_id'));
    final updated = _mergedItem(_trip.days[d].alternatives[a], args);
    await notifier.updateAlternative(d, a, updated);
    return AgentToolOutcome('OK',
        label: 'Zmieniono alternatywę: ${updated.title}');
  }

  Future<AgentToolOutcome> _deleteAlternative(Map<String, dynamic> args) async {
    final (d, a) = _altIdx(_str(args, 'alternative_id'));
    final title = _trip.days[d].alternatives[a].title;
    await notifier.deleteAlternative(d, a);
    return AgentToolOutcome('OK', label: 'Usunięto alternatywę: $title');
  }

  Future<AgentToolOutcome> _setExtraUsed(Map<String, dynamic> args) async {
    final id = _str(args, 'extra_id');
    final used = args['used'];
    if (used is! bool) {
      throw const _ToolError('Parametr "used" musi być typu boolean.');
    }
    final idx = _trip.extras.indexWhere((e) => e.id == id);
    if (idx < 0) throw _ToolError('Nie znaleziono atrakcji extra o ID "$id".');
    final extra = _trip.extras[idx];
    await notifier.updateExtra(idx, extra.copyWith(used: used));
    return AgentToolOutcome('OK',
        label: used
            ? 'Oznaczono extra jako w planie: ${extra.title}'
            : 'Odznaczono extra: ${extra.title}');
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

  Future<AgentToolOutcome> _updatePackingItem(Map<String, dynamic> args) async {
    final id = _str(args, 'packing_id');
    final idx = _trip.packing.indexWhere((p) => p.id == id);
    if (idx < 0) throw _ToolError('Nie znaleziono pozycji pakowania o ID "$id".');
    final old = _trip.packing[idx];
    final updated = PackingItem(
      id: old.id,
      category: args['category'] as String? ?? old.category,
      text: args['text'] as String? ?? old.text,
      userAdded: old.userAdded,
    );
    await notifier.updatePackingItem(idx, updated);
    return AgentToolOutcome('OK', label: 'Zmieniono pakowanie: ${updated.text}');
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
      bestFor:
          (args['best_for'] as List? ?? []).map((e) => e.toString()).toList(),
      duration: args['duration'] as String?,
      location: _locationFromArgs(args),
    );
    await notifier.addExtra(extra);
    return AgentToolOutcome(
      jsonEncode({'extra_id': extra.id}),
      label: 'Dodano atrakcję extra: $title',
    );
  }

  Future<AgentToolOutcome> _updateExtra(Map<String, dynamic> args) async {
    final id = _str(args, 'extra_id');
    final idx = _trip.extras.indexWhere((e) => e.id == id);
    if (idx < 0) throw _ToolError('Nie znaleziono atrakcji extra o ID "$id".');
    final old = _trip.extras[idx];
    final updated = ExtraAttraction(
      id: old.id,
      title: args['title'] as String? ?? old.title,
      category: args['category'] != null
          ? ExtraCategory.fromString(args['category'] as String)
          : old.category,
      drivingTime: args['driving_time'] as String? ?? old.drivingTime,
      totalCostEur: (args['total_cost_eur'] as num?)?.toInt() ?? old.totalCostEur,
      description: args['description'] as String? ?? old.description,
      bestFor: args['best_for'] != null
          ? (args['best_for'] as List).map((e) => e.toString()).toList()
          : old.bestFor,
      duration: args['duration'] as String? ?? old.duration,
      location: _locationFromArgs(args) ?? old.location,
      locations: old.locations,
      used: old.used,
    );
    await notifier.updateExtra(idx, updated);
    return AgentToolOutcome('OK', label: 'Zmieniono extra: ${updated.title}');
  }

  Future<AgentToolOutcome> _deleteExtra(Map<String, dynamic> args) async {
    final id = _str(args, 'extra_id');
    final idx = _trip.extras.indexWhere((e) => e.id == id);
    if (idx < 0) throw _ToolError('Nie znaleziono atrakcji extra o ID "$id".');
    final title = _trip.extras[idx].title;
    await notifier.deleteExtra(idx);
    return AgentToolOutcome('OK', label: 'Usunięto atrakcję extra: $title');
  }

  // ===== Kontakty alarmowe =====

  int _emergencyIdx(String id) {
    final idx = _trip.emergency.indexWhere((e) => e.id == id);
    if (idx < 0) throw _ToolError('Nie znaleziono kontaktu alarmowego o ID "$id".');
    return idx;
  }

  Future<AgentToolOutcome> _addEmergency(Map<String, dynamic> args) async {
    final label = _str(args, 'label');
    final contact = EmergencyContact(
      id: 'custom.${const Uuid().v4()}',
      label: label,
      value: _str(args, 'value'),
      type: ContactType.fromString(args['type'] as String?),
    );
    await notifier.addEmergency(contact);
    return AgentToolOutcome(
      jsonEncode({'emergency_id': contact.id}),
      label: 'Dodano kontakt alarmowy: $label',
    );
  }

  Future<AgentToolOutcome> _updateEmergency(Map<String, dynamic> args) async {
    final idx = _emergencyIdx(_str(args, 'emergency_id'));
    final old = _trip.emergency[idx];
    final updated = EmergencyContact(
      id: old.id,
      label: args['label'] as String? ?? old.label,
      value: args['value'] as String? ?? old.value,
      type: args['type'] != null
          ? ContactType.fromString(args['type'] as String)
          : old.type,
    );
    await notifier.updateEmergency(idx, updated);
    return AgentToolOutcome('OK',
        label: 'Zmieniono kontakt alarmowy: ${updated.label}');
  }

  Future<AgentToolOutcome> _deleteEmergency(Map<String, dynamic> args) async {
    final idx = _emergencyIdx(_str(args, 'emergency_id'));
    final label = _trip.emergency[idx].label;
    await notifier.deleteEmergency(idx);
    return AgentToolOutcome('OK', label: 'Usunięto kontakt alarmowy: $label');
  }

  // ===== Plany B (contingency) =====

  int _contingencyIdx(String id) {
    final idx = _trip.contingency.indexWhere((c) => c.id == id);
    if (idx < 0) throw _ToolError('Nie znaleziono planu B o ID "$id".');
    return idx;
  }

  /// Parsuje listę lokalizacji `[{name, lat, lng}, ...]` z argumentów.
  /// Zwraca null, gdy parametru nie podano (= nie zmieniaj).
  List<Location>? _locationsListFromArgs(Map<String, dynamic> args) {
    if (!args.containsKey('locations')) return null;
    final raw = args['locations'];
    if (raw is! List) {
      throw const _ToolError('Parametr "locations" musi być listą obiektów {name, lat, lng}.');
    }
    return [
      for (final e in raw)
        _locationFromArgs({
          'location_name': (e as Map)['name'],
          'lat': e['lat'],
          'lng': e['lng'],
        }) ??
            (throw const _ToolError('Każda lokalizacja wymaga pól name, lat i lng.')),
    ];
  }

  /// Waliduje day_id z argumentów planu B: '' → null (odpięcie), niepusty
  /// musi wskazywać istniejący dzień.
  String? _contingencyDayId(Map<String, dynamic> args, String? fallback) {
    if (!args.containsKey('day_id')) return fallback;
    final v = args['day_id'] as String?;
    if (v == null || v.isEmpty) return null;
    _dayIdx(v); // rzuca, gdy dzień nie istnieje
    return v;
  }

  Future<AgentToolOutcome> _addContingency(Map<String, dynamic> args) async {
    final trigger = _str(args, 'trigger');
    final c = Contingency(
      id: 'custom.${const Uuid().v4()}',
      trigger: trigger,
      options:
          (args['options'] as List? ?? []).map((e) => e.toString()).toList(),
      dayId: _contingencyDayId(args, null),
      locations: _locationsListFromArgs(args) ?? const [],
    );
    if (c.options.isEmpty) {
      throw const _ToolError('Plan B wymaga co najmniej jednej opcji.');
    }
    await notifier.addContingency(c);
    return AgentToolOutcome(
      jsonEncode({'contingency_id': c.id}),
      label: 'Dodano plan B: $trigger',
    );
  }

  Future<AgentToolOutcome> _updateContingency(Map<String, dynamic> args) async {
    final idx = _contingencyIdx(_str(args, 'contingency_id'));
    final old = _trip.contingency[idx];
    final updated = Contingency(
      id: old.id,
      trigger: args['trigger'] as String? ?? old.trigger,
      options: args['options'] != null
          ? (args['options'] as List).map((e) => e.toString()).toList()
          : old.options,
      dayId: _contingencyDayId(args, old.dayId),
      locations: _locationsListFromArgs(args) ?? old.locations,
    );
    await notifier.updateContingency(idx, updated);
    return AgentToolOutcome('OK', label: 'Zmieniono plan B: ${updated.trigger}');
  }

  Future<AgentToolOutcome> _deleteContingency(Map<String, dynamic> args) async {
    final idx = _contingencyIdx(_str(args, 'contingency_id'));
    final trigger = _trip.contingency[idx].trigger;
    await notifier.deleteContingency(idx);
    return AgentToolOutcome('OK', label: 'Usunięto plan B: $trigger');
  }
}
