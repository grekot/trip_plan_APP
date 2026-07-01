import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/trip_models.dart';

/// Pełnoekranowy wybór lokalizacji.
/// Przekazuj initial przez constructor; zwraca przez Navigator.pop(context, Location?).
/// Zwrot null = anuluj.
class LocationPickerScreen extends StatefulWidget {
  final Location? initial;
  final String title;

  const LocationPickerScreen({super.key, this.initial, this.title = 'Wybierz lokalizację'});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MapController _mapController;
  late TextEditingController _nameCtl;
  late TextEditingController _latCtl;
  late TextEditingController _lngCtl;
  late TextEditingController _searchCtl;
  LatLng? _pos;
  String _nameValue = '';
  Timer? _searchTimer;
  List<_SearchResult> _searchResults = [];
  bool _searching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _nameCtl = TextEditingController(text: widget.initial?.name ?? '');
    _searchCtl = TextEditingController();
    _nameValue = widget.initial?.name ?? '';
    if (widget.initial != null) {
      _pos = LatLng(widget.initial!.lat, widget.initial!.lng);
    }
    _latCtl = TextEditingController(text: _pos != null ? _pos!.latitude.toStringAsFixed(6) : '');
    _lngCtl = TextEditingController(text: _pos != null ? _pos!.longitude.toStringAsFixed(6) : '');
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _nameCtl.dispose();
    _latCtl.dispose();
    _lngCtl.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    setState(() {
      _pos = latlng;
      _latCtl.text = latlng.latitude.toStringAsFixed(6);
      _lngCtl.text = latlng.longitude.toStringAsFixed(6);
    });
  }

  void _onMarkerDrag(LatLng newPos) {
    setState(() {
      _pos = newPos;
      _latCtl.text = newPos.latitude.toStringAsFixed(6);
      _lngCtl.text = newPos.longitude.toStringAsFixed(6);
    });
  }

  void _onLatLngTextChanged() {
    final lat = double.tryParse(_latCtl.text);
    final lng = double.tryParse(_lngCtl.text);
    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      setState(() {
        _pos = LatLng(lat, lng);
      });
      try {
        _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  Future<void> _doSearch(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    setState(() { _searching = true; _showResults = true; });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(query)}&format=json&limit=5&accept-language=pl,en',
      );
      final r = await http.get(url, headers: {
        'User-Agent': 'slowenia-app/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List)
            .map((e) => _SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _searchResults = list;
          _searching = false;
        });
      } else {
        setState(() { _searching = false; });
      }
    } catch (e) {
      setState(() { _searching = false; });
    }
  }

  void _selectSearchResult(_SearchResult r) {
    setState(() {
      _pos = LatLng(r.lat, r.lng);
      _nameCtl.text = r.shortName;
      _nameValue = r.shortName;
      _latCtl.text = r.lat.toStringAsFixed(6);
      _lngCtl.text = r.lng.toStringAsFixed(6);
      _searchResults = [];
      _showResults = false;
      _searchCtl.clear();
    });
    try {
      _mapController.move(LatLng(r.lat, r.lng), 14);
    } catch (_) {}
  }

  void _save() {
    final lat = double.tryParse(_latCtl.text);
    final lng = double.tryParse(_lngCtl.text);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nieprawidłowe lat/lng')));
      return;
    }
    final loc = Location(
      name: _nameCtl.text.trim().isEmpty ? 'Lokalizacja' : _nameCtl.text.trim(),
      lat: lat,
      lng: lng,
    );
    Navigator.of(context).pop(loc);
  }

  void _remove() {
    Navigator.of(context).pop(_RemoveSentinel());
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _pos ?? const LatLng(45.95, 14.50);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.initial != null)
            IconButton(
              tooltip: 'Usuń lokalizację',
              icon: const Icon(Icons.delete_outline),
              onPressed: _remove,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Zapisz'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                    hintText: 'Wyszukaj miejsce (np. „Radovljica Linhartov trg")',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searching
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width:16,height:16,child: CircularProgressIndicator(strokeWidth: 2)))
                        : (_searchCtl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close), onPressed: () { _searchCtl.clear(); setState(() { _searchResults = []; _showResults = false; }); })
                            : null),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) {
                    _searchTimer?.cancel();
                    _searchTimer = Timer(const Duration(milliseconds: 700), () => _doSearch(v));
                  },
                  onSubmitted: _doSearch,
                ),
                if (_showResults && _searchResults.isNotEmpty)
                  Positioned(
                    top: 50, left: 0, right: 0,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (ctx, i) {
                            final r = _searchResults[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined, size: 20),
                              title: Text(r.shortName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(r.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                              onTap: () => _selectSearchResult(r),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: _pos != null ? 13 : 8,
                onTap: _onMapTap,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'pl.grkotarba.slowenia_app',
                  maxNativeZoom: 19,
                ),
                if (_pos != null)
                  DragMarkers(
                    markers: [
                      DragMarker(
                        point: _pos!,
                        size: const Size(36, 36),
                        onDragEnd: (_, latlng) => _onMarkerDrag(latlng),
                        builder: (ctx, point, isDragging) => Icon(
                          Icons.location_on,
                          size: isDragging ? 48 : 40,
                          color: Theme.of(context).colorScheme.primary,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0,2))],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Form fields
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa miejsca',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _nameValue = v,
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _latCtl,
                    decoration: const InputDecoration(labelText: 'Lat', border: OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => _onLatLngTextChanged(),
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: TextField(
                    controller: _lngCtl,
                    decoration: const InputDecoration(labelText: 'Lng', border: OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (_) => _onLatLngTextChanged(),
                  )),
                ]),
                const SizedBox(height: 4),
                Text(
                  _pos == null ? '💡 Tapnij na mapę aby ustawić pin' : '💡 Przeciągnij pin aby poprawić',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marker sentinel oznaczający usunięcie lokalizacji (różny od null = anulowanie).
class _RemoveSentinel {
  const _RemoveSentinel();
}

/// Helper: rozpoznanie rezultatu z LocationPickerScreen.
/// - null → user anulował
/// - _RemoveSentinel → user usunął lokalizację
/// - Location → nowa/zmieniona lokalizacja
Location? readLocationResult(dynamic result) {
  if (result == null) return null;
  if (result is _RemoveSentinel) return null;
  if (result is Location) return result;
  return null;
}

bool isRemoveResult(dynamic result) => result is _RemoveSentinel;

class _SearchResult {
  final String displayName;
  final String shortName;
  final double lat;
  final double lng;
  _SearchResult({required this.displayName, required this.shortName, required this.lat, required this.lng});
  factory _SearchResult.fromJson(Map<String, dynamic> j) {
    final display = j['display_name'] as String? ?? '';
    final parts = display.split(',').map((s) => s.trim()).toList();
    final short = parts.length >= 2 ? '${parts[0]}, ${parts[1]}' : display;
    return _SearchResult(
      displayName: display,
      shortName: short,
      lat: double.tryParse(j['lat']?.toString() ?? '') ?? 0,
      lng: double.tryParse(j['lon']?.toString() ?? '') ?? 0,
    );
  }
}

/// Minimal drag-marker layer for flutter_map.
/// Stwórzmy własny widget bo flutter_map_dragmarker package miałby ekstra zależność.
class DragMarker {
  final LatLng point;
  final Size size;
  final Widget Function(BuildContext, LatLng, bool isDragging) builder;
  final void Function(dynamic, LatLng) onDragEnd;
  DragMarker({required this.point, required this.size, required this.builder, required this.onDragEnd});
}

class DragMarkers extends StatefulWidget {
  final List<DragMarker> markers;
  const DragMarkers({super.key, required this.markers});

  @override
  State<DragMarkers> createState() => _DragMarkersState();
}

class _DragMarkersState extends State<DragMarkers> {
  int? _draggingIdx;
  Offset? _dragOffset;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: widget.markers.asMap().entries.map((entry) {
        final idx = entry.key;
        final m = entry.value;
        return Marker(
          point: m.point,
          width: m.size.width,
          height: m.size.height,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onPanStart: (_) {
              setState(() { _draggingIdx = idx; });
            },
            onPanUpdate: (details) {
              final mapState = MapCamera.of(context);
              final screenPoint = mapState.latLngToScreenPoint(m.point);
              // flutter_map ≥7 używa Point<double> z dart:math, nie Offset
              final newScreenPoint = math.Point<double>(
                screenPoint.x + details.delta.dx,
                screenPoint.y + details.delta.dy,
              );
              final newPoint = mapState.pointToLatLng(newScreenPoint);
              widget.markers[idx] = DragMarker(
                point: newPoint,
                size: m.size,
                builder: m.builder,
                onDragEnd: m.onDragEnd,
              );
              setState(() {});
            },
            onPanEnd: (_) {
              widget.markers[idx].onDragEnd(null, widget.markers[idx].point);
              setState(() { _draggingIdx = null; });
            },
            child: m.builder(context, m.point, _draggingIdx == idx),
          ),
        );
      }).toList(),
    );
  }
}
