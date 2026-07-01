import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trip_models.dart';

/// Rzucane, gdy nie ma wybranego (aktywnego) planu — apka pokazuje wtedy
/// ekran startowy kierujący do Biblioteki planów.
class NoActivePlanException implements Exception {
  const NoActivePlanException();
  @override
  String toString() => 'Brak aktywnego planu';
}

class TripLoadResult {
  final Trip trip;
  final String? warning;
  TripLoadResult(this.trip, {this.warning});
}

/// Ładowanie/zapisywanie planów w modelu WIELOPLANOWYM.
///
/// Plany (odszyfrowane, jawne) leżą w `documents/plans/<id>.json`. Aktywny plan
/// wskazuje klucz `activePlanId` w Hive `box_settings`. Nie ma już bundled
/// `assets/trip.json` — plany pobiera się z chmury (repo trip_plans) przez
/// PlanLibraryService.
class TripLoader {
  static const String _boxSettings = 'box_settings';
  static const String _activeKey = 'activePlanId';

  static Future<Directory> plansDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/plans');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> planFile(String id) async {
    final d = await plansDir();
    return File('${d.path}/$id.json');
  }

  static String? activePlanId() {
    if (!Hive.isBoxOpen(_boxSettings)) return null;
    final v = Hive.box(_boxSettings).get(_activeKey);
    return v is String && v.isNotEmpty ? v : null;
  }

  static Future<void> setActivePlanId(String? id) async {
    final box = Hive.box(_boxSettings);
    if (id == null) {
      await box.delete(_activeKey);
    } else {
      await box.put(_activeKey, id);
    }
  }

  /// Ładuje aktywny plan. Rzuca [NoActivePlanException], gdy nic nie wybrano
  /// lub plik zniknął.
  static Future<TripLoadResult> load() async {
    final id = activePlanId();
    if (id == null) throw const NoActivePlanException();
    final file = await planFile(id);
    if (!await file.exists()) throw const NoActivePlanException();
    final text = await file.readAsString();
    final json = jsonDecode(text) as Map<String, dynamic>;
    return TripLoadResult(Trip.fromJson(json));
  }

  /// Zapisuje edytowany plan do pliku aktywnego planu.
  static Future<void> save(Trip trip) async {
    final id = activePlanId();
    if (id == null) return;
    final file = await planFile(id);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(trip.toJson()));
  }

  /// Zapisuje surowy JSON planu pod danym id (używane przy pobieraniu z chmury
  /// lub imporcie z pliku). Waliduje schemat.
  static Future<void> savePlanJson(String id, String jsonText) async {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Plan nie jest obiektem JSON.');
    }
    final issues = validateSchema(decoded);
    if (issues.isNotEmpty) throw FormatException(issues.first);
    final file = await planFile(id);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(decoded));
  }

  static Future<void> deletePlanFile(String id) async {
    final file = await planFile(id);
    if (await file.exists()) await file.delete();
  }

  static Future<String> exportJsonString(Trip trip) async {
    final encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(trip.toJson());
  }

  static Future<TripImportResult> importFromString(String jsonText) async {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        return TripImportResult.error('Plik nie jest poprawnym JSON-em (oczekiwano obiektu).');
      }
      final issues = validateSchema(decoded);
      if (issues.isNotEmpty) {
        return TripImportResult.error('Walidacja schematu: ${issues.first}');
      }
      final trip = Trip.fromJson(decoded);
      return TripImportResult.success(trip);
    } catch (e) {
      return TripImportResult.error('Błąd parsowania: $e');
    }
  }

  static List<String> validateSchema(Map<String, dynamic> j) {
    final issues = <String>[];
    if (j['version'] is! int) issues.add('Brak lub niepoprawne pole "version".');
    if (j['title'] is! String) issues.add('Brak pola "title".');
    if (j['days'] is! List) issues.add('Pole "days" musi być listą.');
    return issues;
  }

  static TripDiff diff(Trip oldTrip, Trip newTrip) {
    final oldIds = oldTrip.allItems.map((i) => i.id).toSet();
    final newIds = newTrip.allItems.map((i) => i.id).toSet();
    return TripDiff(
      added: newIds.difference(oldIds).length,
      removed: oldIds.difference(newIds).length,
      common: oldIds.intersection(newIds).length,
    );
  }
}

class TripImportResult {
  final Trip? trip;
  final String? error;
  TripImportResult.success(this.trip) : error = null;
  TripImportResult.error(this.error) : trip = null;
  bool get isOk => trip != null;
}

class TripDiff {
  final int added;
  final int removed;
  final int common;
  TripDiff({required this.added, required this.removed, required this.common});
}
