import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'item_edit_screen.dart';
import 'section_edit_screen.dart';

/// Edycja meta dnia + zarządzanie sekcjami (reorder, add, delete).
class DayEditScreen extends ConsumerStatefulWidget {
  final int dayIdx;
  const DayEditScreen({super.key, required this.dayIdx});

  @override
  ConsumerState<DayEditScreen> createState() => _DayEditScreenState();
}

class _DayEditScreenState extends ConsumerState<DayEditScreen> {
  late TextEditingController _idCtl;
  late TextEditingController _titleCtl;
  late TextEditingController _summaryCtl;
  late TextEditingController _numberCtl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final t = ref.read(tripProvider).value;
    final day = t?.days[widget.dayIdx];
    _idCtl = TextEditingController(text: day?.id ?? '');
    _titleCtl = TextEditingController(text: day?.title ?? '');
    _summaryCtl = TextEditingController(text: day?.summary ?? '');
    _numberCtl = TextEditingController(text: (day?.number ?? '').toString());
  }

  @override
  void dispose() {
    _idCtl.dispose();
    _titleCtl.dispose();
    _summaryCtl.dispose();
    _numberCtl.dispose();
    super.dispose();
  }

  Future<void> _saveMeta() async {
    final number = int.tryParse(_numberCtl.text.trim());
    await ref.read(tripProvider.notifier).updateDay(
      widget.dayIdx,
      id: _idCtl.text.trim().isEmpty ? null : _idCtl.text.trim(),
      number: number,
      title: _titleCtl.text.trim().isEmpty ? null : _titleCtl.text.trim(),
      summary: _summaryCtl.text.trim().isEmpty ? null : _summaryCtl.text.trim(),
    );
    setState(() { _dirty = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano metę dnia')));
  }

  Future<void> _deleteDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć cały dzień?'),
        content: const Text('Usunięcie dnia spowoduje też usunięcie wszystkich jego sekcji i punktów. Nie można cofnąć (poza „Przywróć domyślny plan").'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tripProvider.notifier).deleteDay(widget.dayIdx);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addSection() async {
    final ctrl = TextEditingController();
    final twCtrl = TextEditingController();
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nowa sekcja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Tytuł sekcji', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: twCtrl, decoration: const InputDecoration(labelText: 'Okno czasowe (opcjonalnie)', hintText: 'np. 08:00 – 10:00', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Dodaj')),
        ],
      ),
    );
    if (r != true) return;
    if (ctrl.text.trim().isEmpty) return;
    await ref.read(tripProvider.notifier).addSection(
      widget.dayIdx,
      title: ctrl.text.trim(),
      timeWindow: twCtrl.text.trim().isEmpty ? null : twCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider).value;
    if (t == null || widget.dayIdx >= t.days.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final day = t.days[widget.dayIdx];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edycja: Dzień ${day.number}'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Usuń dzień', onPressed: _deleteDay),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: _saveMeta,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Zapisz'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Meta
          TextField(
            controller: _titleCtl,
            decoration: const InputDecoration(labelText: 'Tytuł dnia', border: OutlineInputBorder()),
            onChanged: (_) => setState(() { _dirty = true; }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: _numberCtl,
              decoration: const InputDecoration(labelText: 'Numer dnia', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() { _dirty = true; }),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _idCtl,
              decoration: const InputDecoration(labelText: 'ID', border: OutlineInputBorder()),
              onChanged: (_) => setState(() { _dirty = true; }),
            )),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _summaryCtl,
            decoration: const InputDecoration(labelText: 'Streszczenie', border: OutlineInputBorder()),
            maxLines: 3,
            onChanged: (_) => setState(() { _dirty = true; }),
          ),
          const SizedBox(height: 24),
          // Sekcje
          Row(children: [
            Text('SEKCJE (${day.sections.length})',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, letterSpacing: 0.5)),
            const Spacer(),
            TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('Dodaj'), onPressed: _addSection),
          ]),
          const SizedBox(height: 4),
          if (day.sections.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Brak sekcji. Dodaj pierwszą.', style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: day.sections.length,
              onReorder: (oldIdx, newIdx) {
                ref.read(tripProvider.notifier).reorderSections(widget.dayIdx, oldIdx, newIdx);
              },
              itemBuilder: (ctx, i) {
                final sec = day.sections[i];
                return Card(
                  key: ValueKey(sec.id),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_indicator, color: Colors.grey),
                    ),
                    title: Text(sec.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Row(children: [
                      if (sec.timeWindow != null) ...[
                        const Icon(Icons.schedule, size: 12),
                        const SizedBox(width: 2),
                        Text(sec.timeWindow!, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 8),
                      ],
                      Text('${sec.items.length} pkt.', style: const TextStyle(fontSize: 11)),
                    ]),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SectionEditScreen(dayIdx: widget.dayIdx, secIdx: i),
                      ));
                    },
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          // Alternatives count
          if (day.alternatives.isNotEmpty) ...[
            Text('ALTERNATYWY DLA TEGO DNIA (${day.alternatives.length})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            for (int i = 0; i < day.alternatives.length; i++)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.alt_route, size: 20),
                  title: Text(day.alternatives[i].title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: day.alternatives[i].description != null
                      ? Text(day.alternatives[i].description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ItemEditScreen(
                        dayIdx: widget.dayIdx, sectionIdx: -1, itemIdx: i, isAlternative: true,
                      ),
                    ));
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
