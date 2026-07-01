import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

/// Edycja meta planu: tytuł, podtytuł, summary, version + reorder dni + dodaj dzień.
class TripMetaEditScreen extends ConsumerStatefulWidget {
  const TripMetaEditScreen({super.key});

  @override
  ConsumerState<TripMetaEditScreen> createState() => _TripMetaEditScreenState();
}

class _TripMetaEditScreenState extends ConsumerState<TripMetaEditScreen> {
  late TextEditingController _titleCtl;
  late TextEditingController _subtitleCtl;
  late TextEditingController _summaryCtl;
  late TextEditingController _versionCtl;

  @override
  void initState() {
    super.initState();
    final t = ref.read(tripProvider).valueOrNull;
    _titleCtl = TextEditingController(text: t?.title ?? '');
    _subtitleCtl = TextEditingController(text: t?.subtitle ?? '');
    _summaryCtl = TextEditingController(text: t?.summary ?? '');
    _versionCtl = TextEditingController(text: (t?.version ?? 1).toString());
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _subtitleCtl.dispose();
    _summaryCtl.dispose();
    _versionCtl.dispose();
    super.dispose();
  }

  Future<void> _saveMeta() async {
    await ref.read(tripProvider.notifier).updateMeta(
      title: _titleCtl.text.trim(),
      subtitle: _subtitleCtl.text.trim(),
      summary: _summaryCtl.text.trim(),
      version: int.tryParse(_versionCtl.text.trim()),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano metę planu')));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider).valueOrNull;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edycja planu'),
        actions: [
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
          TextField(controller: _titleCtl, decoration: const InputDecoration(labelText: 'Tytuł', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _subtitleCtl, decoration: const InputDecoration(labelText: 'Podtytuł', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _summaryCtl, decoration: const InputDecoration(labelText: 'Streszczenie', border: OutlineInputBorder()), maxLines: 3),
          const SizedBox(height: 12),
          TextField(controller: _versionCtl, decoration: const InputDecoration(labelText: 'Wersja schematu (integer)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          Row(children: [
            Text('DNI (${t.days.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, letterSpacing: 0.5)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Dodaj dzień'),
              onPressed: () async {
                final ctrl = TextEditingController(text: 'Dzień ${t.days.length + 1}');
                final r = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Nowy dzień'),
                    content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Tytuł', border: OutlineInputBorder())),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Dodaj')),
                    ],
                  ),
                );
                if (r != true) return;
                await ref.read(tripProvider.notifier).addDay(title: ctrl.text.trim());
              },
            ),
          ]),
          const SizedBox(height: 4),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: t.days.length,
            onReorder: (oldIdx, newIdx) => ref.read(tripProvider.notifier).reorderDays(oldIdx, newIdx),
            itemBuilder: (ctx, i) {
              final d = t.days[i];
              return Card(
                key: ValueKey(d.id),
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_indicator, color: Colors.grey),
                  ),
                  title: Text('Dzień ${d.number}: ${d.title}'),
                  subtitle: Text('${d.sections.length} sekcji · ${d.sections.fold<int>(0, (a, s) => a + s.items.length)} pkt', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/edit-day', arguments: {'dayIdx': i}),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
