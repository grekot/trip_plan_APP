import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Wynik lokalizacji „jestem tutaj".
class CurrentPlace {
  final double lat;
  final double lng;
  final String? name;
  const CurrentPlace({required this.lat, required this.lng, this.name});
}

/// GPS + odwrotne geokodowanie (Nominatim/OSM — darmowe, wymaga User-Agent).
class GeoService {
  /// Bieżąca pozycja GPS. Rzuca [GeoException] z polskim komunikatem,
  /// gdy lokalizacja jest wyłączona lub brak zgody.
  static Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const GeoException(
          'Lokalizacja jest wyłączona w systemie — włącz GPS i spróbuj ponownie.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const GeoException(
          'Brak zgody na lokalizację — nadaj uprawnienie w ustawieniach systemu.');
    }
    // geolocator 12.x — parametry płaskie (locationSettings pojawia się w 13+).
    // ignore: deprecated_member_use
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
  }

  /// Nazwa miejsca dla współrzędnych (Nominatim). Zwraca null przy błędzie —
  /// caller pokazuje wtedy same współrzędne.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng'
          '&accept-language=pl&zoom=16');
      final resp = await http.get(uri, headers: {
        // Wymóg Nominatim usage policy — identyfikacja aplikacji.
        'User-Agent': 'PlanPodrozy/1.0 (aplikacja prywatna)',
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final name = j['name'] as String?;
      final addr = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};
      final locality = addr['village'] ?? addr['town'] ?? addr['city'] ?? addr['municipality'];
      if (name != null && name.isNotEmpty) {
        return locality != null && locality != name ? '$name, $locality' : name;
      }
      if (locality != null) return locality.toString();
      return (j['display_name'] as String?)?.split(',').take(2).join(',');
    } catch (_) {
      return null;
    }
  }

  /// Pozycja + nazwa miejsca w jednym kroku.
  static Future<CurrentPlace> currentPlace() async {
    final pos = await currentPosition();
    final name = await reverseGeocode(pos.latitude, pos.longitude);
    return CurrentPlace(lat: pos.latitude, lng: pos.longitude, name: name);
  }
}

class GeoException implements Exception {
  final String message;
  const GeoException(this.message);
  @override
  String toString() => message;
}
