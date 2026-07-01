import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_models.dart';
import '../models/enums.dart';
import '../providers/providers.dart';
import '../widgets/item_tile.dart';
import '../widgets/progress_bar.dart';
import 'day_edit_screen.dart';
import 'section_edit_screen.dart';

class DayDetailScreen extends ConsumerWidget {
  final String dayId;
  const DayDetailScreen({super.key, required this.dayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final scheme = Theme.of(context).colorScheme;

    return tripA.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Błąd: $e'))),
      data: (trip) {
        final day = trip.days.firstWhere(
          (d) => d.id == dayId,
          orElse: () => Day(
              id: dayId,
              number: 0,
              title: 'Nieznany dzień',
              summary: '',
              sections: [],
              alternatives: []),
        );
        final progress = ref.watch(dayProgressProvider(day.id));
        final hiddenCount = day.allItems.where((i) => i.hidden).length;

        final dayIdx = trip.days.indexOf(day);
        return Scaffold(
          appBar: AppBar(
            title: Text('Dzień ${day.number}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edytuj dzień',
                onPressed: dayIdx < 0 ? null : () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DayEditScreen(dayIdx: dayIdx),
                  ));
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'showHidden') _showHiddenDialog(context, day);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'showHidden',
                    enabled: hiddenCount > 0,
                    child: Text(hiddenCount > 0
                        ? 'Pokaż $hiddenCount ukrytych'
                        : 'Brak ukrytych'),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(day.summary, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: DayProgressBar(value: progress)),
                      const SizedBox(width: 8),
                      Text('${(progress * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
              ...day.sections.map((s) => DaySectionView(section: s, dayId: day.id)).toList(),
              if (day.alternatives.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(children: [
                    const Icon(Icons.alt_route),
                    const SizedBox(width: 8),
                    Text('Alternatywy',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.primary)),
                  ]),
                ),
                ...day.alternatives.map((alt) => ItemTile(item: alt)).toList(),
              ],
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  void _showHiddenDialog(BuildContext context, Day day) {
    final hidden = day.allItems.where((i) => i.hidden).toList();
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ukryte punkty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...hidden.map((i) => ItemTile(item: i)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class DaySectionView extends ConsumerWidget {
  final Section section;
  final String dayId;
  const DaySectionView({super.key, required this.section, required this.dayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final visibleItems = section.items.where((i) => !i.hidden).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: scheme.primary)),
                    if (section.timeWindow != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(section.timeWindow!,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dodaj własny punkt',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddDialog(context, ref),
              ),
              IconButton(
                tooltip: 'Edytuj sekcję (kolejność, tytuł)',
                icon: const Icon(Icons.reorder),
                onPressed: () => _openSectionEditor(context, ref),
              ),
            ]),
          ),
          ...visibleItems.map((i) => ItemTile(item: i)).toList(),
        ],
      ),
    );
  }

  /// Otwiera SectionEditScreen — pełen edytor sekcji z drag-reorder punktów,
  /// edycją meta (tytuł, okno czasowe, id), dodawaniem i usuwaniem punktów.
  void _openSectionEditor(BuildContext context, WidgetRef ref) {
    final trip = ref.read(tripProvider).value;
    if (trip == null) return;
    final dayIdx = trip.days.indexWhere((d) => d.id == dayId);
    if (dayIdx < 0) return;
    final secIdx = trip.days[dayIdx].sections.indexWhere((s) => s.id == section.id);
    if (secIdx < 0) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SectionEditScreen(dayIdx: dayIdx, secIdx: secIdx),
    ));
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    ItemType selectedType = ItemType.sightseeing;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Dodaj własny punkt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tytuł', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Opis (opcjonalnie)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ItemType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Typ', border: OutlineInputBorder()),
                items: ItemType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                onChanged: (v) => setState(() { if (v != null) selectedType = v; }),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj'),
                  onPressed: () async {
                    if (titleCtl.text.trim().isEmpty) return;
                    await ref.read(tripProvider.notifier).addCustomItem(
                          dayId: dayId,
                          sectionId: section.id,
                          title: titleCtl.text.trim(),
                          description: descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
                          type: selectedType,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ]),
            ],
          ),
        );
      }),
    );
  }
}
