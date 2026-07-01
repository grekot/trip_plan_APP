import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../widgets/progress_bar.dart';

class DaysOverviewScreen extends ConsumerWidget {
  const DaysOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final activeIdx = ref.watch(activeDayIndexProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Wszystkie dni')),
      body: tripA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (trip) => ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: trip.days.length,
          itemBuilder: (ctx, idx) {
            final d = trip.days[idx];
            final progress = ref.watch(dayProgressProvider(d.id));
            final isActive = activeIdx == idx;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: isActive ? scheme.primary : scheme.outlineVariant,
                    width: isActive ? 2 : 1),
              ),
              child: InkWell(
                onTap: () => context.push('/day/${d.id}'),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                isActive ? scheme.primary : scheme.secondaryContainer,
                            child: Text('${d.number}',
                                style: TextStyle(
                                    color: isActive ? scheme.onPrimary : scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(d.title,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('dzisiaj',
                                  style: TextStyle(
                                      color: scheme.onPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(d.summary,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: DayProgressBar(value: progress)),
                        const SizedBox(width: 8),
                        Text('${(progress * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
