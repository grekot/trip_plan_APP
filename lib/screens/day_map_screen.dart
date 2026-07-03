import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip_models.dart';
import '../providers/providers.dart';
import '../widgets/location_button.dart';

/// Punkt na mapie dnia: element planu + jego pozycja i etykieta markera.
class _MapPoint {
  final Item item;
  final Location location;
  final String label; // "1", "2"… dla planu; "A1", "A2"… dla alternatyw
  final bool isAlternative;
  _MapPoint(this.item, this.location, this.label, this.isAlternative);
}

/// Mapa dnia — wszystkie punkty dnia z lokalizacjami na mapie OSM,
/// ponumerowane w kolejności planu, alternatywy oznaczone osobno.
/// Kafelki wymagają internetu (OpenStreetMap).
class DayMapScreen extends ConsumerWidget {
  final String dayId;
  const DayMapScreen({super.key, required this.dayId});

  List<_MapPoint> _collect(Day day) {
    final points = <_MapPoint>[];
    var n = 0;
    for (final s in day.sections) {
      for (final i in s.items.where((i) => !i.hidden)) {
        final loc = i.location ?? (i.locations.isNotEmpty ? i.locations.first : null);
        if (loc != null) {
          n++;
          points.add(_MapPoint(i, loc, '$n', false));
        }
      }
    }
    var a = 0;
    for (final alt in day.alternatives) {
      final loc = alt.location ?? (alt.locations.isNotEmpty ? alt.locations.first : null);
      if (loc != null) {
        a++;
        points.add(_MapPoint(alt, loc, 'A$a', true));
      }
    }
    return points;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final day = trip?.days.where((d) => d.id == dayId).firstOrNull;
    if (day == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mapa dnia')),
        body: const Center(child: Text('Nie znaleziono dnia')),
      );
    }

    final points = _collect(day);
    if (points.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Mapa — dzień ${day.number}')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Żaden punkt tego dnia nie ma lokalizacji.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final latLngs =
        points.map((p) => LatLng(p.location.lat, p.location.lng)).toList();
    final planRoute = [
      for (final p in points)
        if (!p.isAlternative) LatLng(p.location.lat, p.location.lng),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Mapa — dzień ${day.number}')),
      body: FlutterMap(
        options: latLngs.length == 1
            ? MapOptions(initialCenter: latLngs.first, initialZoom: 13)
            : MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(latLngs),
                  padding: const EdgeInsets.all(48),
                ),
              ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'pl.grkotarba.slowenia_app',
          ),
          if (planRoute.length >= 2)
            PolylineLayer(polylines: [
              Polyline(
                points: planRoute,
                strokeWidth: 3,
                color: scheme.primary.withValues(alpha: 0.5),
              ),
            ]),
          MarkerLayer(markers: [
            for (final p in points)
              Marker(
                point: LatLng(p.location.lat, p.location.lng),
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => _showPoint(context, p, scheme),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.isAlternative ? scheme.tertiary : scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 4),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Text('© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10, color: Colors.black54)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPoint(BuildContext context, _MapPoint p, ColorScheme scheme) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: p.isAlternative ? scheme.tertiary : scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(p.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.item.title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                p.isAlternative
                    ? 'Alternatywa · ${p.item.type.label}'
                    : p.item.type.label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if (p.item.description != null) ...[
                const SizedBox(height: 8),
                Text(p.item.description!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              LocationButton(location: p.location),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
