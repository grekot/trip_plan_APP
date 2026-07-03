import 'dart:convert';
import 'package:http/http.dart' as http;

/// Prognoza dzienna dla jednej daty.
class DayWeather {
  final DateTime date;
  final double tMax;
  final double tMin;
  final int precipProb; // % szansy opadów
  final int weatherCode; // kod WMO

  const DayWeather({
    required this.date,
    required this.tMax,
    required this.tMin,
    required this.precipProb,
    required this.weatherCode,
  });

  /// Polski opis pogody wg kodu WMO.
  String get description => WeatherService.describeCode(weatherCode);
}

/// Prognoza pogody z open-meteo.com — darmowe API bez klucza.
/// Cache w pamięci (per uruchomienie apki), TTL 3h, klucz = zaokrąglone
/// współrzędne — kolejne zapytania o ten sam rejon nie odpytują sieci.
class WeatherService {
  static const _ttl = Duration(hours: 3);
  static final Map<String, (DateTime, List<DayWeather>)> _cache = {};

  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';

  /// Prognoza dzienna na najbliższe 16 dni dla współrzędnych.
  static Future<List<DayWeather>> forecast(double lat, double lng) async {
    final key = _key(lat, lng);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < _ttl) {
      return cached.$2;
    }

    final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code'
        '&timezone=auto&forecast_days=16');
    final resp = await http.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Błąd pobierania prognozy (${resp.statusCode})');
    }
    final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final daily = (j['daily'] as Map).cast<String, dynamic>();
    final dates = (daily['time'] as List).cast<String>();
    final tMax = (daily['temperature_2m_max'] as List);
    final tMin = (daily['temperature_2m_min'] as List);
    final prec = (daily['precipitation_probability_max'] as List);
    final code = (daily['weather_code'] as List);

    final result = <DayWeather>[
      for (var i = 0; i < dates.length; i++)
        DayWeather(
          date: DateTime.parse(dates[i]),
          tMax: (tMax[i] as num?)?.toDouble() ?? 0,
          tMin: (tMin[i] as num?)?.toDouble() ?? 0,
          precipProb: (prec[i] as num?)?.toInt() ?? 0,
          weatherCode: (code[i] as num?)?.toInt() ?? 0,
        ),
    ];
    _cache[key] = (DateTime.now(), result);
    return result;
  }

  /// Prognoza dla konkretnej daty (null, gdy poza zakresem 16 dni).
  static Future<DayWeather?> forDate(
      double lat, double lng, DateTime date) async {
    final list = await forecast(lat, lng);
    final d0 = DateTime(date.year, date.month, date.day);
    for (final w in list) {
      if (w.date.year == d0.year && w.date.month == d0.month && w.date.day == d0.day) {
        return w;
      }
    }
    return null;
  }

  /// Polski opis kodu pogody WMO (open-meteo weather_code).
  static String describeCode(int code) {
    if (code == 0) return 'słonecznie';
    if (code <= 2) return 'częściowe zachmurzenie';
    if (code == 3) return 'pochmurno';
    if (code <= 48) return 'mgła';
    if (code <= 57) return 'mżawka';
    if (code <= 67) return 'deszcz';
    if (code <= 77) return 'śnieg';
    if (code <= 82) return 'przelotne opady';
    if (code <= 86) return 'przelotny śnieg';
    return 'burza';
  }
}
