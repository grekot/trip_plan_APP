import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/trip_models.dart';
import '../providers/providers.dart';
import '../widgets/location_button.dart';
import '../widgets/assistant_fab.dart';

class ExtrasScreen extends ConsumerStatefulWidget {
  const ExtrasScreen({super.key});

  @override
  ConsumerState<ExtrasScreen> createState() => _ExtrasScreenState();
}

class _ExtrasScreenState extends ConsumerState<ExtrasScreen> {
  ExtraCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final tripA = ref.watch(tripProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Atrakcje dodatkowe')),
      floatingActionButton: const AssistantFab(),
      body: tripA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (trip) {
          final all = trip.extras;
          final filtered = _filter == null ? all : all.where((e) => e.category == _filter).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip(null, 'Wszystkie'),
                  ...ExtraCategory.values.map((c) => _chip(c, c.label)),
                ]),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filtered.length,
                itemBuilder: (ctx, idx) {
                  final e = filtered[idx];
                  return _extraCard(context, e, scheme);
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _chip(ExtraCategory? c, String label) {
    final selected = _filter == c;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = selected ? null : c),
      ),
    );
  }

  Widget _extraCard(BuildContext context, ExtraAttraction e, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(e.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              if (e.used)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('✓ w planie',
                      style: TextStyle(fontSize: 11, color: scheme.onTertiaryContainer)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(e.category.label,
                    style: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(e.description, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (e.drivingTime != null)
                _meta(scheme, Icons.directions_car, _humanDuration(e.drivingTime!)),
              if (e.duration != null) _meta(scheme, Icons.timer_outlined, _humanDuration(e.duration!)),
              _meta(scheme, Icons.euro, e.totalCostEur == 0 ? 'darmowe' : '${e.totalCostEur} €'),
            ]),
            if (e.bestFor.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Najlepsze dla: ${e.bestFor.join(", ")}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
            if (e.location != null || e.locations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (e.location != null) LocationButton(location: e.location!),
                ...e.locations.map((l) => LocationButton(location: l)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(ColorScheme scheme, IconData ic, String txt) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(txt, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ]),
      );

  String _humanDuration(String iso) {
    final r = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?');
    final m = r.firstMatch(iso);
    if (m == null) return iso;
    final h = m.group(1);
    final min = m.group(2);
    if (h != null && min != null) return '${h}h ${min}min';
    if (h != null) return '${h}h';
    if (min != null) return '${min}min';
    return iso;
  }
}
