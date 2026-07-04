import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trip_models.dart';
import 'crypto_service.dart';

class PlanPushException implements Exception {
  final String message;
  const PlanPushException(this.message);
  @override
  String toString() => message;
}

/// Wysyłanie planu z aplikacji do repo `trip_plans` (GitHub Contents API).
/// Odwrotność [PlanLibraryService]: plan jest szyfrowany tym samym hasłem
/// i wgrywany jako plan-NNNN.enc + aktualizacja manifest.enc. Na PC:
/// `git pull` w repo i `dart run tool/encrypt_plan.dart dec …` do edycji.
class PlanPushService {
  static const _owner = 'grekot';
  static const _repo = 'trip_plans';
  static const _branch = 'main';
  static const _apiBase =
      'https://api.github.com/repos/$_owner/$_repo/contents/';
  static const _timeout = Duration(seconds: 30);

  static Map<String, String> _headers(String token) => {
        'authorization': 'Bearer $token',
        'accept': 'application/vnd.github+json',
        'user-agent': 'plan-podrozy-app',
        'x-github-api-version': '2022-11-28',
      };

  /// Pobiera plik przez Contents API → (treść, sha) albo null przy 404.
  static Future<({String text, String sha})?> _getFile(
      String token, String path) async {
    final r = await http
        .get(Uri.parse('$_apiBase$path?ref=$_branch'), headers: _headers(token))
        .timeout(_timeout);
    if (r.statusCode == 404) return null;
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw const PlanPushException(
          'GitHub odrzucił token — sprawdź, czy token jest ważny i ma '
          'uprawnienie Contents (Read and write) do repo trip_plans.');
    }
    if (r.statusCode != 200) {
      throw PlanPushException('Błąd GitHub API (${r.statusCode}).');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final content = (j['content'] as String).replaceAll(RegExp(r'\s'), '');
    return (
      text: utf8.decode(base64.decode(content)),
      sha: j['sha'] as String,
    );
  }

  static Future<void> _putFile(String token, String path, String text,
      String? sha, String message) async {
    final r = await http
        .put(
          Uri.parse('$_apiBase$path'),
          headers: _headers(token),
          body: jsonEncode({
            'message': message,
            'content': base64.encode(utf8.encode(text)),
            'branch': _branch,
            if (sha != null) 'sha': sha,
          }),
        )
        .timeout(_timeout);
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw const PlanPushException(
          'GitHub odrzucił token — sprawdź uprawnienie Contents (Read and '
          'write) do repo trip_plans.');
    }
    if (r.statusCode == 409 || r.statusCode == 422) {
      throw const PlanPushException(
          'Konflikt wersji w repo (coś zmieniło pliki w międzyczasie) — '
          'spróbuj ponownie.');
    }
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw PlanPushException('Błąd zapisu do GitHub (${r.statusCode}).');
    }
  }

  /// Pierwszy wolny plik plan-NNNN.enc (dla planu, którego nie ma w manifeście).
  static String _nextFile(List<Map<String, dynamic>> plans) {
    var maxN = 0;
    for (final p in plans) {
      final m = RegExp(r'^plan-(\d+)\.enc$').firstMatch(p['file'] as String? ?? '');
      if (m != null) {
        final n = int.parse(m.group(1)!);
        if (n > maxN) maxN = n;
      }
    }
    return 'plan-${(maxN + 1).toString().padLeft(4, '0')}.enc';
  }

  /// Szyfruje i wysyła [trip] do chmury; aktualizuje manifest.
  /// Zwraca nazwę pliku planu w repo.
  static Future<String> push({
    required Trip trip,
    required String planId,
    required String passphrase,
    required String token,
  }) async {
    // 1. Manifest (może nie istnieć w świeżym repo).
    final mf = await _getFile(token, 'manifest.enc');
    Map<String, dynamic> manifest;
    if (mf == null) {
      manifest = {'plans': <Map<String, dynamic>>[]};
    } else {
      // Złe hasło rzuci CryptoException z czytelnym komunikatem.
      manifest = jsonDecode(await CryptoService.decrypt(mf.text, passphrase))
          as Map<String, dynamic>;
    }
    final plans = (manifest['plans'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // 2. Wpis manifestu: istniejący plan (po id) → ten sam plik; nowy → kolejny.
    final idx = plans.indexWhere((p) => p['id'] == planId);
    final file = idx >= 0 ? plans[idx]['file'] as String : _nextFile(plans);
    final entry = <String, dynamic>{
      'id': planId,
      'file': file,
      'title': trip.title,
      if (trip.subtitle != null) 'subtitle': trip.subtitle,
      'updated': DateTime.now().toIso8601String().substring(0, 10),
    };
    if (idx >= 0) {
      plans[idx] = entry;
    } else {
      plans.add(entry);
    }
    manifest['plans'] = plans;

    // 3. Plan: szyfrowanie + PUT (sha wymagany przy nadpisaniu).
    final planJson = const JsonEncoder.withIndent('  ').convert(trip.toJson());
    final planEnc = await CryptoService.encrypt(planJson, passphrase);
    final existingPlan = await _getFile(token, file);
    await _putFile(token, file, planEnc, existingPlan?.sha,
        'Plan "${trip.title}" z aplikacji');

    // 4. Manifest: szyfrowanie + PUT (pole updated zmienia się zawsze).
    final manifestEnc = await CryptoService.encrypt(
        const JsonEncoder.withIndent('  ').convert(manifest), passphrase);
    await _putFile(token, 'manifest.enc', manifestEnc, mf?.sha,
        'Manifest: "${trip.title}" z aplikacji');

    return file;
  }
}
