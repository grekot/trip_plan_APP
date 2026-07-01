import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/trip_models.dart';
import '../providers/providers.dart';
import 'location_picker_screen.dart';

/// Lista atrakcji extra + przejście do edycji pojedynczej.
class ExtrasEditListScreen extends ConsumerWidget {
  const ExtrasEditListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tripProvider).valueOrNull;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edycja: Atrakcje dodatkowe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Dodaj atrakcję',
            onPressed: () async {
              final newExtra = ExtraAttraction(
                id: 'custom.${const Uuid().v4()}',
                title: 'Nowa atrakcja',
                category: ExtraCategory.halfday,
                totalCostEur: 0,
                description: '',
                bestFor: [],
              );
              await ref.read(tripProvider.notifier).addExtra(newExtra);
              if (context.mounted) {
                final newT = ref.read(tripProvider).value!;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ExtraEditScreen(idx: newT.extras.length - 1),
                ));
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: t.extras.length,
        itemBuilder: (ctx, i) {
          final e = t.extras[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              title: Text(e.title),
              subtitle: Text('${e.category.label} · ${e.totalCostEur} €', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExtraEditScreen(idx: i))),
            ),
          );
        },
      ),
    );
  }
}

class ExtraEditScreen extends ConsumerStatefulWidget {
  final int idx;
  const ExtraEditScreen({super.key, required this.idx});

  @override
  ConsumerState<ExtraEditScreen> createState() => _ExtraEditScreenState();
}

class _ExtraEditScreenState extends ConsumerState<ExtraEditScreen> {
  late TextEditingController _idCtl;
  late TextEditingController _titleCtl;
  late TextEditingController _descCtl;
  late TextEditingController _drivingTimeCtl;
  late TextEditingController _durationCtl;
  late TextEditingController _costCtl;
  late ExtraCategory _category;
  late Location? _location;
  late List<String> _bestFor;

  @override
  void initState() {
    super.initState();
    final t = ref.read(tripProvider).value;
    final ex = t?.extras[widget.idx];
    _idCtl = TextEditingController(text: ex?.id ?? '');
    _titleCtl = TextEditingController(text: ex?.title ?? '');
    _descCtl = TextEditingController(text: ex?.description ?? '');
    _drivingTimeCtl = TextEditingController(text: ex?.drivingTime ?? '');
    _durationCtl = TextEditingController(text: ex?.duration ?? '');
    _costCtl = TextEditingController(text: ex?.totalCostEur.toString() ?? '0');
    _category = ex?.category ?? ExtraCategory.halfday;
    _location = ex?.location;
    _bestFor = [...(ex?.bestFor ?? [])];
  }

  @override
  void dispose() {
    _idCtl.dispose();
    _titleCtl.dispose();
    _descCtl.dispose();
    _drivingTimeCtl.dispose();
    _durationCtl.dispose();
    _costCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = ref.read(tripProvider).value;
    if (t == null) return;
    final cost = int.tryParse(_costCtl.text.trim()) ?? 0;
    final updated = ExtraAttraction(
      id: _idCtl.text.trim().isEmpty ? 'custom.${const Uuid().v4()}' : _idCtl.text.trim(),
      title: _titleCtl.text.trim(),
      category: _category,
      drivingTime: _drivingTimeCtl.text.trim().isEmpty ? null : _drivingTimeCtl.text.trim(),
      totalCostEur: cost,
      description: _descCtl.text.trim(),
      bestFor: _bestFor.where((s) => s.trim().isNotEmpty).toList(),
      duration: _durationCtl.text.trim().isEmpty ? null : _durationCtl.text.trim(),
      location: _location,
    );
    await ref.read(tripProvider.notifier).updateExtra(widget.idx, updated);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć atrakcję?'),
        content: Text('Usunąć „${_titleCtl.text}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Usuń')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tripProvider.notifier).deleteExtra(widget.idx);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickLocation() async {
    final r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LocationPickerScreen(initial: _location),
    ));
    if (isRemoveResult(r)) {
      setState(() { _location = null; });
    } else if (r is Location) {
      setState(() { _location = r; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edycja atrakcji'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
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
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _titleCtl, decoration: const InputDecoration(labelText: 'Tytuł *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<ExtraCategory>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Kategoria', border: OutlineInputBorder()),
          items: ExtraCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
          onChanged: (v) => setState(() { if (v != null) _category = v; }),
        ),
        const SizedBox(height: 12),
        TextField(controller: _descCtl, decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder()), maxLines: 4),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _drivingTimeCtl, decoration: const InputDecoration(labelText: 'Dojazd (PT15M)', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _durationCtl, decoration: const InputDecoration(labelText: 'Czas pobytu', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _costCtl, decoration: const InputDecoration(labelText: 'Koszt łączny (€)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        // Location
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📍 LOKALIZACJA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            if (_location == null)
              OutlinedButton.icon(onPressed: _pickLocation, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Dodaj lokalizację'))
            else ...[
              Text(_location!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${_location!.lat.toStringAsFixed(4)}, ${_location!.lng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                OutlinedButton.icon(onPressed: _pickLocation, icon: const Icon(Icons.edit_location_alt_outlined, size: 16), label: const Text('Edytuj')),
                TextButton.icon(onPressed: () => setState(() { _location = null; }), icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), label: const Text('Usuń', style: TextStyle(color: Colors.red))),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // bestFor
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🎯 NAJLEPSZE DLA (bestFor)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            for (int i = 0; i < _bestFor.length; i++)
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                Expanded(child: TextField(
                  controller: TextEditingController(text: _bestFor[i])..selection = TextSelection.collapsed(offset: _bestFor[i].length),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  onChanged: (v) => _bestFor[i] = v,
                )),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { _bestFor.removeAt(i); })),
              ])),
            TextButton.icon(onPressed: () => setState(() { _bestFor.add(''); }), icon: const Icon(Icons.add, size: 18), label: const Text('Dodaj')),
          ]),
        ),
      ]),
    );
  }
}
