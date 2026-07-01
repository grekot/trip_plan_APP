import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../data/trip_loader.dart';
import 'crypto_service.dart';

/// Wpis w zaszyfrowanym manifeście — plan dostępny do pobrania z chmury.
class PlanManifestEntry {
  final String id;
  final String file;
  final String title;
  final String? subtitle;
  final String? updated;
  PlanManifestEntry({
    required this.id,
    required this.file,
    required this.title,
    this.subtitle,
    this.updated,
  });
  factory PlanManifestEntry.fromJson(Map<String, dynamic> j) => PlanManifestEntry(
        id: j['id'] as String,
        file: j['file'] as String,
        title: (j['title'] as String?) ?? (j['id'] as String),
        subtitle: j['subtitle'] as String?,
        updated: j['updated'] as String?,
      );
}

/// Plan pobrany lokalnie (odszyfrowany, w documents/plans/<id>.json).
class DownloadedPlan {
  final String id;
  final String title;
  final String? subtitle;
  DownloadedPlan({required this.id, required this.title, this.subtitle});
}

/// Pobieranie zaszyfrowanych planów z publicznego repo `trip_plans`,
/// odszyfrowanie hasłem i zapis lokalny (jawnie).
class PlanLibraryService {
  /// Baza raw GitHub repo z planami. Zmień, jeśli przeniesiesz repo.
  static const String repoBase =
      'https://raw.githubusercontent.com/grekot/trip_plans/main/';

  static const Map<String, String> _headers = {'User-Agent': 'plan-podrozy-app'};

  /// Pobiera i odszyfrowuje manifest → lista planów dostępnych w chmurze.
  static Future<List<PlanManifestEntry>> fetchAvailable(String passphrase) async {
    final r = await http.get(Uri.parse('${repoBase}manifest.enc'), headers: _headers);
    if (r.statusCode == 404) {
      throw Exception('Brak manifestu w repo (nie dodano jeszcze planów).');
    }
    if (r.statusCode != 200) {
      throw Exception('Nie udało się pobrać listy planów (HTTP ${r.statusCode}).');
    }
    final clear = await CryptoService.decrypt(utf8.decode(r.bodyBytes), passphrase);
    final j = jsonDecode(clear) as Map<String, dynamic>;
    final plans = (j['plans'] as List).cast<Map<String, dynamic>>();
    return plans.map(PlanManifestEntry.fromJson).toList();
  }

  /// Pobiera, odszyfrowuje i zapisuje plan lokalnie (waliduje schemat).
  /// Zwraca id zapisanego planu.
  static Future<String> download(PlanManifestEntry e, String passphrase) async {
    final r = await http.get(Uri.parse('${repoBase}${e.file}'), headers: _headers);
    if (r.statusCode != 200) {
      throw Exception('Nie udało się pobrać planu (HTTP ${r.statusCode}).');
    }
    final clear = await CryptoService.decrypt(utf8.decode(r.bodyBytes), passphrase);
    await TripLoader.savePlanJson(e.id, clear);
    return e.id;
  }

  /// Lista planów pobranych lokalnie — czytana wprost z plików planów
  /// (tytuł/subtitle z każdego JSON-a).
  static Future<List<DownloadedPlan>> listDownloaded() async {
    final d = await TripLoader.plansDir();
    final out = <DownloadedPlan>[];
    for (final entity in d.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final id = entity.uri.pathSegments.last.replaceAll(RegExp(r'\.json$'), '');
        out.add(DownloadedPlan(
          id: id,
          title: (j['title'] as String?) ?? id,
          subtitle: j['subtitle'] as String?,
        ));
      } catch (_) {
        // pomijamy uszkodzone pliki
      }
    }
    out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return out;
  }

  /// Usuwa pobrany plan. Jeśli był aktywny — czyści wskazanie aktywnego.
  static Future<void> delete(String id) async {
    await TripLoader.deletePlanFile(id);
    if (TripLoader.activePlanId() == id) {
      await TripLoader.setActivePlanId(null);
    }
  }
}
