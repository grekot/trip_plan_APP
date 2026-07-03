import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/emergency_button.dart';
import '../widgets/location_button.dart';
import '../widgets/assistant_fab.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Awaryjne')),
      floatingActionButton: const AssistantFab(),
      body: tripA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (trip) => ListView(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 80),
          children: [
            for (final c in trip.emergency)
              EmergencyButton(
                label: c.label,
                value: c.value,
                icon: c.label.toLowerCase().contains('alarm')
                    ? Icons.local_hospital
                    : Icons.phone,
              ),
            const SizedBox(height: 16),
            if (trip.contingency.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  Icon(Icons.umbrella, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Plany B',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: scheme.primary)),
                ]),
              ),
              for (final c in trip.contingency)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(c.trigger,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          if (c.dayId != null)
                            Builder(builder: (_) {
                              final dayNum = trip.days
                                  .where((d) => d.id == c.dayId)
                                  .map((d) => d.number)
                                  .firstOrNull;
                              if (dayNum == null) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Dzień $dayNum',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSecondaryContainer)),
                              );
                            }),
                        ]),
                        const SizedBox(height: 6),
                        for (final o in c.options)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6, right: 6),
                                child: Icon(Icons.fiber_manual_record, size: 6),
                              ),
                              Expanded(child: Text(o)),
                            ]),
                          ),
                        if (c.locations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final l in c.locations) LocationButton(location: l),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
