import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_models.dart';
import '../providers/providers.dart';

class PackingScreen extends ConsumerWidget {
  const PackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final packing = ref.watch(packingProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pakowanie'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reset checklisty'),
                    content: const Text('Odhaczyć wszystkie pozycje pakowania?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
                      FilledButton(
                          onPressed: () async {
                            await ref.read(packingProvider.notifier).reset();
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Reset')),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'reset', child: Text('Reset checklisty')),
            ],
          ),
        ],
      ),
      body: tripA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (trip) {
          final byCategory = <String, List<PackingItem>>{};
          for (final p in trip.packing) {
            byCategory.putIfAbsent(p.category, () => []).add(p);
          }
          final total = trip.packing.length;
          final done = trip.packing.where((p) => packing[p.id] == true).length;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$done / $total', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  for (final entry in byCategory.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(entry.key,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: scheme.primary, fontSize: 14)),
                    ),
                    for (final p in entry.value)
                      Card(
                        child: CheckboxListTile(
                          value: packing[p.id] ?? false,
                          onChanged: (_) => ref.read(packingProvider.notifier).toggle(p.id),
                          title: Text(p.text),
                          secondary: p.userAdded
                              ? Icon(Icons.edit_note, color: scheme.tertiary)
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }
}
