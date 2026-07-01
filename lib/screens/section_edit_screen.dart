import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/trip_models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'item_edit_screen.dart';

/// Edycja meta sekcji + zarządzanie punktami (reorder, add, delete, edit).
class SectionEditScreen extends ConsumerStatefulWidget {
  final int dayIdx;
  final int secIdx;
  const SectionEditScreen({super.key, required this.dayIdx, required this.secIdx});

  @override
  ConsumerState<SectionEditScreen> createState() => _SectionEditScreenState();
}

class _SectionEditScreenState extends ConsumerState<SectionEditScreen> {
  late TextEditingController _idCtl;
  late TextEditingController _titleCtl;
  late TextEditingController _timeWindowCtl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final t = ref.read(tripProvider).value;
    final sec = t?.days[widget.dayIdx].sections[widget.secIdx];
    _idCtl = TextEditingController(text: sec?.id ?? '');
    _titleCtl = TextEditingController(text: sec?.title ?? '');
    _timeWindowCtl = TextEditingController(text: sec?.timeWindow ?? '');
  }

  @override
  void dispose() {
    _idCtl.dispose();
    _titleCtl.dispose();
    _timeWindowCtl.dispose();
    super.dispose();
  }

  Future<void> _saveMeta() async {
    await ref.read(tripProvider.notifier).updateSection(
      widget.dayIdx, widget.secIdx,
      id: _idCtl.text.trim().isEmpty ? null : _idCtl.text.trim(),
      title: _titleCtl.text.trim().isEmpty ? null : _titleCtl.text.trim(),
      timeWindow: _timeWindowCtl.text.trim().isEmpty ? null : _timeWindowCtl.text.trim(),
    );
    setState(() { _dirty = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano')));
  }

  Future<void> _deleteSection() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć sekcję?'),
        content: const Text('Usunięcie sekcji spowoduje też usunięcie wszystkich jej punktów.'),
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
    await ref.read(tripProvider.notifier).deleteSection(widget.dayIdx, widget.secIdx);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addItem() async {
    final ctrl = TextEditingController();
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nowy punkt'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Tytuł', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Dodaj')),
        ],
      ),
    );
    if (r != true || ctrl.text.trim().isEmpty) return;
    final t = ref.read(tripProvider).value;
    if (t == null) return;
    final secId = t.days[widget.dayIdx].sections[widget.secIdx].id;
    final dayId = t.days[widget.dayIdx].id;
    final newId = await ref.read(tripProvider.notifier).addCustomItem(
      dayId: dayId, sectionId: secId, title: ctrl.text.trim(),
    );
    if (newId.isNotEmpty && mounted) {
      final newT = ref.read(tripProvider).value;
      if (newT == null) return;
      final newIdx = newT.days[widget.dayIdx].sections[widget.secIdx].items.length - 1;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ItemEditScreen(
          dayIdx: widget.dayIdx, sectionIdx: widget.secIdx, itemIdx: newIdx,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider).value;
    if (t == null ||
        widget.dayIdx >= t.days.length ||
        widget.secIdx >= t.days[widget.dayIdx].sections.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final day = t.days[widget.dayIdx];
    final sec = day.sections[widget.secIdx];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sekcja: ${sec.title}'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Usuń sekcję', onPressed: _deleteSection),
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
          Text('Dzień ${day.number}: ${day.title}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtl,
            decoration: const InputDecoration(labelText: 'Tytuł sekcji', border: OutlineInputBorder()),
            onChanged: (_) => setState(() { _dirty = true; }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: _timeWindowCtl,
              decoration: const InputDecoration(labelText: 'Okno czasowe', hintText: 'np. 08:00 – 10:00', border: OutlineInputBorder()),
              onChanged: (_) => setState(() { _dirty = true; }),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _idCtl,
              decoration: const InputDecoration(labelText: 'ID', border: OutlineInputBorder()),
              onChanged: (_) => setState(() { _dirty = true; }),
            )),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Text('PUNKTY (${sec.items.length})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, letterSpacing: 0.5)),
            const Spacer(),
            TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('Dodaj'), onPressed: _addItem),
          ]),
          const SizedBox(height: 4),
          if (sec.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Text('Brak punktów. Dodaj pierwszy.', style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: sec.items.length,
              onReorder: (oldIdx, newIdx) {
                ref.read(tripProvider.notifier).reorderItems(widget.dayIdx, widget.secIdx, oldIdx, newIdx);
              },
              itemBuilder: (ctx, i) {
                final it = sec.items[i];
                return Card(
                  key: ValueKey(it.id),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: it.hidden ? scheme.surfaceContainerHighest : null,
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_indicator, color: Colors.grey),
                    ),
                    title: Row(children: [
                      Icon(TypeStyling.iconFor(it.type), size: 16, color: TypeStyling.colorFor(it.type, scheme)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            decoration: it.hidden ? TextDecoration.lineThrough : null,
                          ))),
                      if (it.userAdded) const Icon(Icons.edit_note, size: 16, color: Colors.purple),
                      if (it.location != null) const Icon(Icons.place, size: 14, color: Colors.green),
                    ]),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ItemEditScreen(
                          dayIdx: widget.dayIdx, sectionIdx: widget.secIdx, itemIdx: i,
                        ),
                      ));
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
