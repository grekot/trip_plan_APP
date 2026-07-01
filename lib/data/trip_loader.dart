import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/trip_models.dart';

class TripLoadResult {
  final Trip trip;
  final String? warning;
  TripLoadResult(this.trip, {this.warning});
}

class TripLoader {
  static const String _assetPath = 'assets/trip.json';
  static const String _fileName = 'trip.json';

  static Future<File> _writableFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<TripLoadResult> load() async {
    final file = await _writableFile();
    if (!await file.exists()) {
      final assetText = await rootBundle.loadString(_assetPath);
      await file.writeAsString(assetText);
    }
    final text = await file.readAsString();
    final json = jsonDecode(text) as Map<String, dynamic>;
    return TripLoadResult(Trip.fromJson(json));
  }

  static Future<void> save(Trip trip) async {
    final file = await _writableFile();
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(trip.toJson()));
  }

  static Future<String> exportJsonString(Trip trip) async {
    final encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(trip.toJson());
  }

  /// Przywraca domyślny plan z bundled asseta — nadpisuje writeable kopię.
  /// Zwraca załadowany Trip z domyślnego asseta.
  static Future<Trip> restoreDefault() async {
    final assetText = await rootBundle.loadString(_assetPath);
    final file = await _writableFile();
    await file.writeAsString(assetText);
    final json = jsonDecode(assetText) as Map<String, dynamic>;
    return Trip.fromJson(json);
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
