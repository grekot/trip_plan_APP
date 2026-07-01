import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Owner/repo GitHub, z którego pobierane są wydania APK.
/// Zmień, jeśli przeniesiesz repo w inne miejsce.
const String kOtaRepoOwner = 'grekot';
const String kOtaRepoName = 'trip_plan_APP';

/// Wynik sprawdzenia dostępności aktualizacji.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String? apkUrl;
  final String? releaseNotes;
  final String? releaseUrl;
  final bool isNewer;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.isNewer,
  });
}

/// Serwis obsługi Over-The-Air update — sprawdza GitHub Releases, pobiera APK
/// i uruchamia systemowego instalatora. Na Windows/desktopie: fallback do
/// otwarcia strony releases w przeglądarce (brak natywnego mechanizmu).
class OtaService {
  static const _apiUrl = 'https://api.github.com/repos/$kOtaRepoOwner/$kOtaRepoName/releases/latest';
  static const _releasesPage = 'https://github.com/$kOtaRepoOwner/$kOtaRepoName/releases';

  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Zwraca informacje o aktualizacji lub null, jeśli:
  ///  - brak opublikowanych wydań (404 z GitHub),
  ///  - błąd sieci (silent — traktujemy jak brak aktualizacji, żeby nie krzyczeć).
  /// Rzuca wyjątek tylko dla naprawdę nieoczekiwanych stanów (nie-404 błąd HTTP).
  static Future<UpdateInfo?> checkForUpdate({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final response = await c.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));

      // 404 = brak wydań. Nie jest to błąd — użytkownik po prostu ma najnowszą.
      if (response.statusCode == 404) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          apkUrl: null,
          releaseNotes: null,
          releaseUrl: _releasesPage,
          isNewer: false,
        );
      }
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?)?.replaceFirst(RegExp('^v'), '') ?? '';
      final body = data['body'] as String?;
      final htmlUrl = data['html_url'] as String?;

      // Wybierz pierwszy asset z .apk.
      String? apkUrl;
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is Map<String, dynamic>) {
            final name = a['name'] as String?;
            if (name != null && name.toLowerCase().endsWith('.apk')) {
              apkUrl = a['browser_download_url'] as String?;
              break;
            }
          }
        }
      }

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: tag,
        apkUrl: apkUrl,
        releaseNotes: body,
        releaseUrl: htmlUrl ?? _releasesPage,
        isNewer: tag.isNotEmpty && _isNewer(tag, currentVersion),
      );
    } finally {
      if (client == null) c.close();
    }
  }

  /// Porównuje wersje semver — zwraca true jeśli `candidate` jest wyższa niż `current`.
  static bool _isNewer(String candidate, String current) {
    List<int> parts(String v) => v
        .split(RegExp(r'[.+\-]'))
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final a = parts(candidate);
    final b = parts(current);
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// GitHub browser_download_url zwraca 302 do objects.githubusercontent.com.
  /// Część silników HTTP na Androidzie nie idzie za przekierowaniami między hostami —
  /// pobiera niepełny plik, instalacja wisi. Rozwiń URL do finalnego bezpośredniego linku.
  static Future<String> resolveFinalUrl(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      var current = url;
      for (var i = 0; i < 6; i++) {
        final req = await client.getUrl(Uri.parse(current))
          ..followRedirects = false;
        final res = await req.close();
        if (res.statusCode >= 300 && res.statusCode < 400) {
          final loc = res.headers.value(HttpHeaders.locationHeader);
          unawaited(res.drain<void>());
          if (loc == null) break;
          current = Uri.parse(current).resolve(loc).toString();
        } else {
          unawaited(res.drain<void>());
          break;
        }
      }
      return current;
    } finally {
      client.close(force: true);
    }
  }

  /// Uruchamia pobieranie APK i systemowego instalatora. Zwraca Stream zdarzeń
  /// pobierania — użyj w UI do wyświetlania postępu i wyłapywania błędów.
  ///
  /// Ważne:
  ///  - `apkUrl` musi być rozwiniętym linkiem (patrz [resolveFinalUrl]).
  ///  - Nazwa pliku zawiera wersję — inaczej po nieudanym pobraniu instalator
  ///    wziąłby stary plik i wersja by się nie zmieniła.
  static Stream<OtaEvent> downloadAndInstall(String apkUrl, String version) {
    final safeVer = version.replaceAll(RegExp(r'[^0-9A-Za-z.]'), '');
    return OtaUpdate().execute(
      apkUrl,
      destinationFilename: 'slowenia-app-$safeVer.apk',
    );
  }

  /// Sprawdza, czy status oznacza błąd — do wyświetlenia w UI.
  static bool isErrorStatus(OtaStatus? status) {
    return status == OtaStatus.DOWNLOAD_ERROR ||
        status == OtaStatus.INTERNAL_ERROR ||
        status == OtaStatus.CHECKSUM_ERROR ||
        status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR;
  }

  /// Otwiera stronę Releases w przeglądarce (Windows/desktop fallback).
  static Future<void> openReleasesPage() async {
    await launchUrl(
      Uri.parse(_releasesPage),
      mode: LaunchMode.externalApplication,
    );
  }
}
